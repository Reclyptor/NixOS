/* Forces the X11 window class of a Steam game to steam_app_<appid>.
 *
 * Proton games already arrive that way -- wine derives WM_CLASS from
 * SteamGameId -- which is why window rules keyed on ^(steam_app_[0-9]+)$ have
 * always worked for them and never once matched a native Linux game. Native
 * games name themselves after whatever their engine feels like, so every rule
 * has to be written per title.
 *
 * There is no environment variable that fixes this across engines. SDL honours
 * SDL_VIDEO_X11_WMCLASS and GLFW honours RESOURCE_NAME, but Ren'Py overwrites
 * the SDL one unconditionally from its own config before the window is ever
 * created (renpy/display/core.py), and Godot reads neither. What every one of
 * them does share is the Xlib call underneath, so that is where this sits: the
 * four public entry points that carry an XClassHint get the class rewritten on
 * the way through.
 *
 * Inert unless SteamAppId (or SteamGameId) names a game, so it is safe in any
 * process that happens to inherit it through the launcher chain.
 */

#define _GNU_SOURCE

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

/* "steam_app_" + a 32-bit appid, with room to spare. */
#define CLASS_MAX 32

static int steam_class(char *buffer, size_t size)
{
    const char *appid = getenv("SteamAppId");

    if (!appid || !*appid)
        appid = getenv("SteamGameId");
    if (!appid || !*appid)
        return 0;

    /* Anything that is not a bare appid means this is not the environment the
       rewrite was meant for, and a class built from it would be nonsense. */
    if (appid[strspn(appid, "0123456789")] != '\0')
        return 0;

    return snprintf(buffer, size, "steam_app_%s", appid) > 0;
}

/* Both fields are rewritten. Hyprland matches on the class, but leaving the
   instance name behind would describe a window that no longer exists. */
static XClassHint *force(XClassHint *original, XClassHint *storage, char *class_name)
{
    if (original)
        *storage = *original;
    storage->res_name = class_name;
    storage->res_class = class_name;
    return storage;
}

int XSetClassHint(Display *display, Window window, XClassHint *hints)
{
    static int (*real)(Display *, Window, XClassHint *);
    XClassHint forced;
    char class_name[CLASS_MAX];

    if (!real)
        real = dlsym(RTLD_NEXT, "XSetClassHint");
    if (!real)
        return 0;

    if (steam_class(class_name, sizeof class_name))
        hints = force(hints, &forced, class_name);

    return real(display, window, hints);
}

void XSetWMProperties(Display *display, Window window, XTextProperty *window_name,
                      XTextProperty *icon_name, char **argv, int argc,
                      XSizeHints *normal_hints, XWMHints *wm_hints, XClassHint *class_hints)
{
    static void (*real)(Display *, Window, XTextProperty *, XTextProperty *, char **, int,
                        XSizeHints *, XWMHints *, XClassHint *);
    XClassHint forced;
    char class_name[CLASS_MAX];

    if (!real)
        real = dlsym(RTLD_NEXT, "XSetWMProperties");
    if (!real)
        return;

    if (steam_class(class_name, sizeof class_name))
        class_hints = force(class_hints, &forced, class_name);

    real(display, window, window_name, icon_name, argv, argc, normal_hints, wm_hints, class_hints);
}

void XmbSetWMProperties(Display *display, Window window, const char *window_name,
                        const char *icon_name, char **argv, int argc,
                        XSizeHints *normal_hints, XWMHints *wm_hints, XClassHint *class_hints)
{
    static void (*real)(Display *, Window, const char *, const char *, char **, int,
                        XSizeHints *, XWMHints *, XClassHint *);
    XClassHint forced;
    char class_name[CLASS_MAX];

    if (!real)
        real = dlsym(RTLD_NEXT, "XmbSetWMProperties");
    if (!real)
        return;

    if (steam_class(class_name, sizeof class_name))
        class_hints = force(class_hints, &forced, class_name);

    real(display, window, window_name, icon_name, argv, argc, normal_hints, wm_hints, class_hints);
}

void Xutf8SetWMProperties(Display *display, Window window, const char *window_name,
                          const char *icon_name, char **argv, int argc,
                          XSizeHints *normal_hints, XWMHints *wm_hints, XClassHint *class_hints)
{
    static void (*real)(Display *, Window, const char *, const char *, char **, int,
                        XSizeHints *, XWMHints *, XClassHint *);
    XClassHint forced;
    char class_name[CLASS_MAX];

    if (!real)
        real = dlsym(RTLD_NEXT, "Xutf8SetWMProperties");
    if (!real)
        return;

    if (steam_class(class_name, sizeof class_name))
        class_hints = force(class_hints, &forced, class_name);

    real(display, window, window_name, icon_name, argv, argc, normal_hints, wm_hints, class_hints);
}
