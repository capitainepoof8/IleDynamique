// Aide de lecture : expose le « À l'écoute » du système (toutes les apps) à Île Dynamique.
//
// Depuis macOS 15.4, MediaRemote ne répond qu'aux processus Apple. Cette bibliothèque est donc
// chargée dans /usr/bin/perl (voir AideLecture.swift), qui y a encore accès.
//
// Protocole : une ligne JSON par changement sur stdout ; une commande par ligne sur stdin
// (playpause, next, prev, refresh). La fin de stdin (app quittée) termine le processus.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <unistd.h>

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*GetIsPlayingFn)(dispatch_queue_t, void (^)(BOOL));
typedef void (*GetClientFn)(dispatch_queue_t, void (^)(id));
typedef NSString *(*ClientBundleFn)(id);
typedef void (*RegisterFn)(dispatch_queue_t);
typedef BOOL (*SendCommandFn)(int, NSDictionary *);

// Valeurs de l'énumération MRMediaRemoteCommand.
enum { kCommandeBascule = 2, kCommandeSuivant = 4, kCommandePrecedent = 5 };

static GetInfoFn sGetInfo;
static GetIsPlayingFn sGetIsPlaying;
static GetClientFn sGetClient;
static ClientBundleFn sClientBundle, sClientParent;
static SendCommandFn sSendCommand;

static NSUInteger sGeneration;
static NSString *sClePochette;
static NSData *sDernierePochette;

static void ecrireLigne(NSDictionary *message) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:NULL];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static NSString *texte(NSDictionary *infos, NSString *cle) {
    id valeur = infos[cle];
    return [valeur isKindOfClass:[NSString class]] ? valeur : @"";
}

static double nombre(NSDictionary *infos, NSString *cle) {
    id valeur = infos[cle];
    return [valeur isKindOfClass:[NSNumber class]] ? [valeur doubleValue] : 0;
}

static void emettre(NSDictionary *infos, BOOL enLecture, NSString *bundle) {
    NSMutableDictionary *message = [@{
        @"titre": texte(infos, @"kMRMediaRemoteNowPlayingInfoTitle"),
        @"artiste": texte(infos, @"kMRMediaRemoteNowPlayingInfoArtist"),
        @"album": texte(infos, @"kMRMediaRemoteNowPlayingInfoAlbum"),
        @"duree": @(nombre(infos, @"kMRMediaRemoteNowPlayingInfoDuration")),
        @"enLecture": @(enLecture),
        @"bundle": bundle ?: @"",
    } mutableCopy];

    // Position extrapolée à maintenant : l'horodatage peut dater de plusieurs secondes.
    double position = nombre(infos, @"kMRMediaRemoteNowPlayingInfoElapsedTime");
    id horodatage = infos[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    double vitesse = nombre(infos, @"kMRMediaRemoteNowPlayingInfoPlaybackRate");
    if (enLecture && [horodatage isKindOfClass:[NSDate class]] && vitesse > 0) {
        position += -[horodatage timeIntervalSinceNow] * vitesse;
    }
    message[@"position"] = @(MAX(0, position));

    // La pochette n'est envoyée que si elle change. Une mise à jour sans pochette pour le même
    // morceau ne l'efface pas : les apps la publient souvent dans un second temps.
    NSString *identifiant = texte(infos, @"kMRMediaRemoteNowPlayingInfoArtworkIdentifier");
    NSString *cle = identifiant.length > 0
        ? identifiant
        : [NSString stringWithFormat:@"%@|%@", message[@"titre"], message[@"artiste"]];
    id donnees = infos[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    if ([donnees isKindOfClass:[NSData class]] && [donnees length] > 0) {
        if (![donnees isEqualToData:sDernierePochette]) {
            sDernierePochette = donnees;
            message[@"pochette"] = [donnees base64EncodedStringWithOptions:0];
        }
    } else if (![cle isEqualToString:sClePochette] && sDernierePochette) {
        sDernierePochette = nil;
        message[@"pochetteRetiree"] = @YES;
    }
    sClePochette = cle;

    ecrireLigne(message);
}

static void lireEtat(void) {
    NSUInteger generation = ++sGeneration;
    dispatch_queue_t file = dispatch_get_main_queue();

    sGetInfo(file, ^(CFDictionaryRef brut) {
        if (generation != sGeneration) return;
        NSDictionary *infos = (__bridge NSDictionary *)brut ?: @{};
        double vitesse = nombre(infos, @"kMRMediaRemoteNowPlayingInfoPlaybackRate");

        void (^suite)(BOOL) = ^(BOOL enLecture) {
            if (generation != sGeneration) return;
            if (!sGetClient || !sClientBundle) {
                emettre(infos, enLecture, nil);
                return;
            }
            sGetClient(file, ^(id client) {
                if (generation != sGeneration) return;
                // Navigateurs : le lecteur est un sous-processus, l'app utile est son parent.
                NSString *bundle = client && sClientParent ? sClientParent(client) : nil;
                if (bundle.length == 0 && client) bundle = sClientBundle(client);
                emettre(infos, enLecture, bundle);
            });
        };

        if (sGetIsPlaying) {
            sGetIsPlaying(file, suite);
        } else {
            suite(vitesse > 0);
        }
    });
}

// Plusieurs notifications arrivent en rafale pour un seul changement.
static void planifierLecture(void) {
    static dispatch_block_t enAttente;
    if (enAttente) dispatch_block_cancel(enAttente);
    enAttente = dispatch_block_create(0, ^{ lireEtat(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), enAttente);
}

static void executerCommande(NSString *commande) {
    if ([commande isEqualToString:@"refresh"]) {
        planifierLecture();
    } else if (sSendCommand && [commande isEqualToString:@"playpause"]) {
        sSendCommand(kCommandeBascule, nil);
    } else if (sSendCommand && [commande isEqualToString:@"next"]) {
        sSendCommand(kCommandeSuivant, nil);
    } else if (sSendCommand && [commande isEqualToString:@"prev"]) {
        sSendCommand(kCommandePrecedent, nil);
    }
}

static void ecouterCommandes(void) {
    static NSMutableData *tampon;
    tampon = [NSMutableData data];
    static dispatch_source_t source;
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(source, ^{
        char octets[256];
        ssize_t lus = read(STDIN_FILENO, octets, sizeof octets);
        if (lus <= 0) exit(0);
        [tampon appendBytes:octets length:(NSUInteger)lus];
        NSRange fin;
        while ((fin = [tampon rangeOfData:[NSData dataWithBytes:"\n" length:1]
                                  options:0
                                    range:NSMakeRange(0, tampon.length)]).location != NSNotFound) {
            NSData *ligne = [tampon subdataWithRange:NSMakeRange(0, fin.location)];
            [tampon replaceBytesInRange:NSMakeRange(0, fin.location + 1) withBytes:NULL length:0];
            NSString *commande = [[NSString alloc] initWithData:ligne encoding:NSUTF8StringEncoding];
            if (commande) executerCommande(commande);
        }
    });
    dispatch_resume(source);
}

// Installée comme XSUB par perl : ne rend jamais la main, le processus vit dans cette boucle.
__attribute__((visibility("default")))
void aide_lecture_demarrer(void *interpreteur, void *routine) {
    void *mr = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    RegisterFn enregistrer = mr ? (RegisterFn)dlsym(mr, "MRMediaRemoteRegisterForNowPlayingNotifications") : NULL;
    sGetInfo = mr ? (GetInfoFn)dlsym(mr, "MRMediaRemoteGetNowPlayingInfo") : NULL;
    if (!enregistrer || !sGetInfo) {
        fprintf(stderr, "IleDynamique : MediaRemote indisponible\n");
        exit(2);
    }
    sGetIsPlaying = (GetIsPlayingFn)dlsym(mr, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    sGetClient = (GetClientFn)dlsym(mr, "MRMediaRemoteGetNowPlayingClient");
    sClientBundle = (ClientBundleFn)dlsym(mr, "MRNowPlayingClientGetBundleIdentifier");
    sClientParent = (ClientBundleFn)dlsym(mr, "MRNowPlayingClientGetParentAppBundleIdentifier");
    sSendCommand = (SendCommandFn)dlsym(mr, "MRMediaRemoteSendCommand");

    NSNotificationCenter *centre = NSNotificationCenter.defaultCenter;
    for (NSString *nom in @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    ]) {
        [centre addObserverForName:nom object:nil queue:nil usingBlock:^(NSNotification *note) {
            planifierLecture();
        }];
    }
    enregistrer(dispatch_get_main_queue());

    ecouterCommandes();
    lireEtat();
    [NSRunLoop.mainRunLoop run];
    exit(0);
}
