;;; indicators.el --- display the relative location of line in the fringe.

;; Copyright (C) 2013 Matus Goljer

;; Author: Matus Goljer <matus.goljer@gmail.com>
;; Maintainer: Matus Goljer <matus.goljer@gmail.com>
;; Created: 16 Feb 2013
;; Version: 0.0.1
;; Keywords: fringe frames
;; URL: https://github.com/Fuco1/indicators.el

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; See github readme at https://github.com/Fuco1/indicators.el

;; Known limitations:
;;
;; 1. you can't have more than one color on one "physical line".
;;    This is becuse fringes operate on "per-line" basis and it is
;;    only possible to set face for bitmap for the whole line.
;; 2. if you are at the end of file the indicators are displaied
;;    incorrectly. This is because it's impossible to set fringe
;;    bitmaps for lines past the end of file.
;;
;; Both of these are currently imposible to fix.

;;; Code:

(require 'fringe)

(defvar ind-managed-indicators nil
  "Managed indicators.  Position of these on the fringe is
automatically updated when window properties change.

These are managed automatically by `indicators-mode'.  However,
you can manage your own lists and pass them to `ind-update'
function to be updated.")
(make-variable-buffer-local 'ind-managed-indicators)

(defun ind--pos-at-line (line)
  "Return the starting point of LINE."
  (save-excursion
    (goto-line line)
    (point)))

(defun ind--line-at-pos (pos)
  "Return the line at position POS."
  (count-lines (point-min) pos))

(defmacro ind--number-of-lines ()
  "Return number of lines in buffer."
  (1- (line-number-at-pos (point-max))))

(defun ind-update-event-handler (&optional a b c d e f g h)
  "Function that is called by the hooks to redraw the fringe bitmaps."
  (ignore-errors
    (ind-update)))

(defvar ind-indicator-height 1
  "Height of an indicator in pixels.
The value of 1 works best, but values up to `frame-char-height'
are possible.")

(defun ind-update (&optional mlist)
  "Update managed indicators.
If optional argument LIST is non-nil update indicators on that list."
  (interactive)
  (let ((managed-list (or mlist (bound-and-true-p ind-managed-indicators))))
    (when managed-list
      (let* ((max-line (ind--number-of-lines))
             (height (min max-line (window-body-height)))
             (px-height (* height (frame-char-height)))
             ind-list
             buckets buckets-face)
        ;; here we need to compute the values of functions (if there
        ;; are some) on this managed-list and then sort it
        (setq ind-list (sort (mapcar (lambda (pair) (cons (ind--get-indicator-pos (car pair))
                                                          (cdr pair))) managed-list)
                             (lambda (a b) (< (car a) (car b)))))
        ;; next we need to compute their relative "pixel" positions
        (setq ind-list
              (mapcar (lambda (pair)
                        (cons (floor (* (/ (float (ind--line-at-pos (car pair))) (float max-line))
                                        (float px-height)))
                              (cdr pair)))
                      ind-list))
        ;; parition the indicators into buckets for the same line
        (mapc (lambda (pair)
                (let* ((line (/ (car pair) (frame-char-height)))
                       (ov-line (1+ (% (car pair) (frame-char-height)))))
                  (if (plist-member buckets line)
                      (let ((bucket (plist-get buckets line))
                            (bucket-face (plist-get buckets-face line)))
                        (setq buckets
                              (plist-put buckets line
                                         (push ov-line bucket)))
                        (when (> (plist-get (cdr pair) :priority)
                                 (plist-get bucket-face :priority))
                          (setq buckets-face (plist-put buckets-face line (cdr pair)))))
                    (setq buckets (plist-put buckets line (list ov-line)))
                    (setq buckets-face (plist-put buckets-face line (cdr pair))))))
              ind-list)
        ;; and now create the overlays
        (remove-overlays (point-min) (point-max) 'ind-indicator t)
        (let ((top (window-start)))
          (while buckets
            (let* ((line (car buckets))
                   (line-ov (cadr buckets))
                   (line-bitmap (make-symbol (concat "ovbitmap" (int-to-string line))))
                   (fringe-display-prop (list 'right-fringe
                                              line-bitmap
                                              (plist-get (cadr buckets-face) :face)))
                   (fringe-text (propertize "!" 'display fringe-display-prop))
                   (ov (make-overlay 1 1)))
              (overlay-put ov 'before-string fringe-text)
              (overlay-put ov 'priority (plist-get (cadr buckets-face) :priority))
              (overlay-put ov 'ind-indicator t)
              (define-fringe-bitmap line-bitmap (ind--create-bitmap line-ov))
              (save-excursion
                (goto-char top)
                (forward-line line)
                (move-overlay ov (point) (point))))
            (setq buckets (cddr buckets))
            (setq buckets-face (cddr buckets-face))))))))

(defun ind--create-bitmap (lines)
  "Create the bitmap according to LINES.

LINES is a list of numbers where each number indicate there
should be a line drawn on that line in the bitmap.  The numbers
of lines need to be in reverse order.

For example arugment (10 5 1) will return a bitmap [255 0 0 0 255
0 0 0 0 255 0 0 0 0 0] for 15 pixel high line."
  (let (lst (it (frame-char-height)))
    (while (> it 0)
      (if (not (member it lines))
          (progn
            (push 0 lst)
            (setq it (1- it)))
        (dotimes (i ind-indicator-height)
          (push 255 lst))
        (setq it (- it ind-indicator-height))))
    (vconcat lst)))

(defun ind--get-indicator-pos (pos-or-fun)
  "Return the beginning position for line on which POS-OR-FUN is.
POS-OR-FUN can be an integer, marker or a function.

If POS-OR-FUN is a nullary function this function is used to get
a buffer position P, then position of the beginning of line on
which P is is returned."
  (let ((pos (if (integer-or-marker-p pos-or-fun)
                 pos-or-fun
               (funcall pos-or-fun))))
    (save-excursion
      (goto-char pos)
      (beginning-of-line)
      (point))))

(defun* ind-create-indicator-at-line (line
                                      &key
                                      (marker nil)
                                      (managed nil)
                                      (face font-lock-warning-face)
                                      (priority 10))
  "Add an indicator on LINE.

If optional keyword argument MARKER is t create a dynamic
indicator on this line.  That means the indicator position
updates as the text is inserted/removed.

See `ind-create-indicator' for values of optional arguments."
  (let* ((pal (ind--pos-at-line line))
         (pos (if marker
                  (let ((m (point-marker)))
                    (set-marker m pal))
                pal)))
    (ind-create-indicator pos
                          :managed managed
                          :face face
                          :priority priority)))

(defun* ind-create-indicator-at-marker (point
                                     &key
                                     (managed nil)
                                     (face font-lock-warning-face)
                                     (priority 10))
  "Add a dynamic indicator on position POINT.
That means the indicator position updates as the text is inserted/removed.

See `ind-create-indicator' for values of optional arguments."
  (let ((m (point-marker)))
    (set-marker m point)
    (ind-create-indicator m
                       :managed managed
                       :face face
                       :priority priority)))

(defun* ind-create-indicator (pos
                              &key
                              (managed nil)
                              (face font-lock-warning-face)
                              (priority 10))
  "Add an indicator to position POS.

Keyword argument FACE is a face to use when displaying the bitmap
for this indicator.  Default value is `font-lock-warning-face'.

Keyword argument PRIORITY determines the face of the bitmap if
more indicators are on the same physical line.  Default value is
10."
  (when (and (not indicators-mode)
             managed)
    (indicators-mode t))
  (let ((indicator (cons pos (list :face face :priority priority))))
    (when managed
      (push indicator ind-managed-indicators)
      (ind-update))
    indicator))

(defun ind-clear-indicators ()
  "Remove all indicators managed by `indicators-mode'."
  (remove-overlays (point-min) (point-max) 'ind-indicator t)
  (setq ind-managed-indicators nil))

(define-minor-mode indicators-mode
  "Toggle indicators mode."
  :init-value nil
  :lighter " Ind"
  :group 'indicators-mode
  (if indicators-mode
      (progn
        (add-hook 'window-scroll-functions 'ind-update-event-handler nil t)
        (add-hook 'window-configuration-change-hook 'ind-update-event-handler nil t)
        (add-hook 'after-change-functions 'ind-update-event-handler nil t))
    (remove-hook 'window-scroll-functions 'ind-update-event-handler t)
    (remove-hook 'window-configuration-change-hook 'ind-update-event-handler t)
    (remove-hook 'after-change-functions 'ind-update-event-handler t)
    (ind-clear-indicators)))

(provide 'indicators)

;;; indicators.el ends here
