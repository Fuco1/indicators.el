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

# How to update indicators

To turn on automatic updates of managed indicators simply enable `indicators-mode` in the buffer. This mode is automatically enabled when you add your first managed indicator in this buffer.

To manually update lists of your own indicators or indicators managed by your package call `(ind-update my-list-of-indicators)`. The items on this list should be indicators as returned by some of the `ind-create-indicator[-*]` function (see next section).

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

To create a non-relative indicator use keyword argument `:relative nil`. For these, you can also specify a bitmap to use using `:bitmap 'name-of-bitmap`. See variable `fringe-bitmaps` for a list of built-in bitmaps.

```scheme
;; create an arrow indicator at line 20
(ind-create-indicator-at-line 20 :relative nil :bitmap 'left-arrow)
```
