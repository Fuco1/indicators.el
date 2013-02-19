# indicators.el

In emacs, displaying fringe indicators is done via text overlays. In that way, bitmaps in the fringe are attached to the lines of text shown in the buffer window.

This works nicely when the fringe is used to indicate information that is relevant to the adjacent line; for example, text overflow, or something similar. But, there isn't a simple way for an application or module to use the fringe to display buffer-relative information -- for example, the location of compiler error messages.

Using the fringe to communicate this kind of information -- buffer-relative positions -- is probably more intuitive and is certainly more useful for the user.

This package is heavily inspired by [RFringe](http://www.emacswiki.org/emacs/RFringe). However, there are some notable differences:

* **indicators.el offers per-pixel resolution. This means it's able to display multiple indicators on one line instead of just one for all that would potentionally fall there (as RFringe does).**
* indicators.el provides minor mode `indicators-mode` so you can quickly remove and disable the display of managed indicators. You can still manage your indicators manually and call `(ind-update my-indicators)` to update them manually (or from your own package).
* Instead of only positions, you can also add indicators to lines or "functions".
    * Indicators on lines point to a line (same line you would get with `goto-line`).
    * Indicators on functions compute their position from a function. To add a simple indicator of buffer-relative position you can therefore call `(ind-create-indicator 'point :managed t)`. On each update, the value of `(point)` is used for this indicator's position.
* Indicators can be static or dynamic. Static indicators always point to the same position. Dynamic indicators update their position if the buffer content is updated (using standard Emacs LISP markers). You can use this to add indicators on functions or section headers and they will automatically update their positions if you add more text/code in the buffer.
* You can specify the face for the indicator.
* You can also create non-relative indicators that simply sit at given position.

# Indicator types

There are two fundamental types of indicators: relative and absolute. Relative indicators display line-position relative to buffer size scaled to the height of the window (similar to how classical scrollbars show you relative position in the window). Absolute indicators are attached to a specific position or line and are displayed only if that line is visible.

# How to update indicators

This package is mostly ment to provide a simple interface for your own packages to use indicators. It is therefore expected you will create and manage indicator lists in your own code.

However, this package provides two lists, one for relative and one for absolute indicators, that are managed automatically. To turn on automatic updates for indicators managed by this package simply enable `indicators-mode` in the buffer. This mode is automatically enabled when you add your first managed indicator in current buffer. To create managed indicators use `:managed t` keyword (see next section).

The managed indicators are updated on events: `window-scroll-functions`, `window-configuration-change-hook`, `after-change-functions`.

To manually update lists of your own *relative* indicators call `(ind-update my-list-of-indicators)`. The items on this list should be relative indicators as returned by some of the `ind-create-indicator[-*]` function (see next section).

To manually update lists of your own *absolute* indicators call `(ind-update-absolute my-list-of-indicators)`. The items on this list should be absolute indicators as returned by some of the `ind-create-indicator[-*]` funciton (see next section).

You can register your lists with `indicators-mode` so they will become automatically managed too. This is the simplest way to manage the indicators and you should use it whenever possible.

To let `indicators-mode` manage your relative indicators, simply use:

```scheme
(add-to-list 'ind-managed-list-relative 'my-list-variable)
```

To let `indicators-mode` manage your absolute indicators, simply use:

```scheme
(add-to-list 'ind-managed-list-absolute 'my-list-variable)
```

The list variable you add should be a quoted symbol. Its value will be automatically fetched by `indicators-mode`.

# How to create indicators

To create your own indicator use:

```scheme
;; create static indicator at position 1337
(ind-create-indicator 1337 :dynamic nil)

;; create dynamic indicator with initial position 2238
(ind-create-indicator 2238 :dynamic t)

;; create static indicator at line 15
(ind-create-indicator-at-line 15 :dynamic nil)

;; create dynamic indicator at line 30. By default dynamic indicators are created.
(ind-create-indicator-at-line 30)
```

All indicators are automatically buffer-local.

If you want `indicators-mode` to automatically manage the indicator, use the keyword argument `:managed t`

```scheme
;; create managed static indicator at position of (point).  Each time
;; `ind-update' is called this value is recomputed using `point'
;; function
(ind-create-indicator 'point :managed t)

;; create managed dynamic indicator at initial position 1000.
(ind-create-indicator 1000 :managed t :dynamic t)
```

To style your indicators use keyword argument `:face name-of-face`. If multiple indicators fall on the same physical line they will inherit the color of the indicator with highest priority (this is a limitation of emacs fringes and cannot be fixed). You can specify the priority with keyword argument `:priority number`. Default priority is 10, default face is `font-lock-warning-face`.

```scheme
(ind-create-indicator-at-line 12 :face font-lock-constant-face :priority 100)
```

To create a non-relative indicator use keyword argument `:relative nil`. For these, you can also specify a bitmap to use using `:bitmap 'name-of-bitmap`. See variable `fringe-bitmaps` for a list of built-in bitmaps. You can also use package [fringe-helper.el](http://nschum.de/src/emacs/fringe-helper/) to draw new bitmaps.

```scheme
;; create an arrow indicator at line 20
(ind-create-indicator-at-line 20 :relative nil :bitmap 'left-arrow)
```

You can also specify the fringe where the indicator should be placed using the keyword argument `:fringe` with values `'left-fringe` or `'right-fringe`

```scheme
(ind-create-indicator-at-line 215
                              :managed t
                              :fringe 'left-fringe
                              :relative nil
                              :bitmap 'question-mark
                              :priority 200)
```

# More examples

```scheme
;; show a little arrow at the end of buffer using the default fringe face
(ind-create-indicator 'point-max
                      :managed t
                      :relative nil
                      :fringe 'left-fringe
                      :bitmap 'right-arrow
                      :face 'fringe)

;; show relative position in the file (a.k.a. scroll bar)
(ind-create-indicator 'point :managed t)
```

# Packages using indicators.el

- [Indicate change](https://github.com/renard/indicate-change): adds indicators on the lines that has changed in real time (i.e. "real time diff").
