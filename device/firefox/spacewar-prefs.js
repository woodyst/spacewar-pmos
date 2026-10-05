// /usr/lib/firefox-esr/defaults/pref/spacewar-prefs.js — spacewar (2026-09-14)
//
// Vídeo en segundo plano (con la pantalla apagada o en otra app). Lo instala scripts/97-firefox.sh junto con la
// extensión «Video Background Play Fix» (video-bg-play@timdream.org) en el perfil. Son valores por defecto: se pueden
// cambiar en about:config. Fichero propio, no del paquete: sobrevive a las actualizaciones de Firefox.

// No dejar de descodificar el vídeo de una pestaña oculta
pref("media.suspend-background-video.enabled", false);
// Que el siguiente vídeo de una lista pueda empezar aunque Firefox no esté delante
pref("media.block-autoplay-until-in-foreground", false);
// Las extensiones copiadas a la carpeta extensions/ del perfil se activan sin preguntar (ámbito de perfil = 1;
// el valor de fábrica, 15, las deja desactivadas)
pref("extensions.autoDisableScopes", 14);
