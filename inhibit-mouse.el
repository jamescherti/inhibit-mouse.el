;;; inhibit-mouse.el --- Deactivate mouse input (alternative to disable-mouse) -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 James Cherti | https://www.jamescherti.com/contact/

;; Author: James Cherti <https://www.jamescherti.com/contact/>
;; Version: 1.0.2
;; URL: https://github.com/jamescherti/inhibit-mouse.el
;; Keywords: convenience
;; Package-Requires: ((emacs "24.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; The inhibit-mouse package allows the disabling of mouse input in Emacs using
;; inhibit-mouse-mode.
;;
;; Instead of modifying the keymap of its own mode (as the disable-mouse package
;; does), enabling inhibit-mouse-mode only modifies input-decode-map to disable
;; mouse events, making it more efficient and faster than disable-mouse.
;;
;; Additionally, the inhibit-mouse package allows for the restoration of mouse
;; input when inhibit-mouse-mode is disabled.
;;
;; Installation from MELPA:
;; ------------------------
;; (use-package inhibit-mouse
;;   :commands inhibit-mouse-mode
;;   :hook (after-init . inhibit-mouse-mode))
;;
;; Usage:
;; ------
;; You can enable or disable inhibit-mouse-mode using:
;;   (inhibit-mouse-mode)
;;
;; Links:
;; ------
;; - inhibit-mouse.el @GitHub:
;;   https://github.com/jamescherti/inhibit-mouse.el

;;; Code:

(defgroup inhibit-mouse nil
  "Non-nil if inhibit-mouse mode mode is enabled."
  :group 'inhibit-mouse
  :prefix "inhibit-mouse-"
  :link '(url-link
          :tag "Github"
          "https://github.com/jamescherti/inhibit-mouse.el"))

(defcustom inhibit-mouse-mode-lighter " InhibitMouse"
  "Mode-line lighter for `inhibit-mouse-mode'."
  :group 'inhibit-mouse
  :type 'string)

(defcustom inhibit-mouse-button-numbers '(1 2 3 4 5)
  "List of mouse button numbers to inhibit."
  :type '(repeat integer)
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-button-events
  '("mouse"
    "up-mouse"
    "down-mouse"
    "drag-mouse")
  "List of mouse button events to be inhibited."
  :type '(repeat string)
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-misc-events
  '("wheel-up"
    "wheel-down"
    "wheel-left"
    "wheel-right"
    "pinch")
  "List of miscellaneous mouse events to be inhibited."
  :type '(repeat string)
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-multipliers
  '("double" "triple")
  "List of mouse multiplier events to be inhibited."
  :type '(repeat string)
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-key-modifiers
  '((control)
    (meta)
    (shift)
    (control meta shift)
    (control meta)
    (control shift)
    (meta shift))
  "List of key modifier combinations to be inhibited for mouse events."
  :type '(repeat (set (const control) (const meta) (const shift)))
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-adjust-mouse-highlight t
  "If non-nil, disables mouse hover highlighting over clickable text.
When this variable is set, it dynamically adjusts the `mouse-highlight'
behavior, preventing visual feedback (highlighting) when the mouse pointer
hovers over clickable text (e.g., URLs). This setting ensures that clickable
text does not receive the standard hover indication.

When `inhibit-mouse-mode' is disabled, the `mouse-highlight' behavior is
reverted to its original value."
  :type 'boolean
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-adjust-show-help-function nil
  "If non-nil, disables the use of tooltips via `show-help-function'.
This prevents contextual help tooltips or messages from being displayed in
response to mouse interactions, effectively stopping the invocation of
`show-help-function'.

When `inhibit-mouse-mode' is disabled, the `show-help-function' behavior is
reverted to its original value."
  :type 'boolean
  :group 'inhibit-mouse)

(defcustom inhibit-mouse-predicate nil
  "Function to determine whether a mouse event should be ignored.
It takes three arguments: (modifiers, base, value) and returns:
- t if the mouse event should be ignored,
- nil if the mouse event should not be ignored,
- A function that takes one argument and returns a vector to assign to the mouse
event instead of the default `inhibit-mouse--default-mouse-event'. For more
details, refer to the `input-decode-map' documentation."
  :group 'inhibit-mouse
  :type '(choice (const nil)
                 (function)))

(defvar inhibit-mouse--ignored-events nil
  "The mouse events that have been ignored. This is an internal variable.")

(defvar inhibit-mouse--backup-show-help-function nil)
(defvar inhibit-mouse--backup-mouse-highlight nil)

(defun inhibit-mouse--define-input-event (modifiers base value)
  "Suppress a specific input event.

This function disables an input event defined by the combination of
MODIFIERS and BASE, modifying the `input-decode-map` to ensure that
the specified event is not processed or is remapped to a specified VALUE.

MODIFIERS: A list of modifier keys as symbols (e.g., (control meta)).
BASE: The base input event (e.g., wheel-up) to be suppressed.
VALUE: The value to associate with the suppressed input event, which can
       be nil to ignore the event or another function or command to remap it.

The function is useful for disabling or remapping unwanted mouse events
during editing or other operations, allowing users to maintain focus on
keyboard input without interruption from mouse actions."
  (let ((predicate-result
         (or (not inhibit-mouse-predicate)
             (funcall inhibit-mouse-predicate modifiers base value))))
    (when predicate-result
      (when (functionp predicate-result)
        (setq value predicate-result))
      (when value
        (push (cons modifiers base) inhibit-mouse--ignored-events))
      (define-key input-decode-map
                  (vector (event-convert-list (append modifiers (list base))))
                  value))))

(defun inhibit-mouse--default-mouse-event (_arg)
  "Return a vector for a default mouse event.
Used in `input-decode-map' for disabled keys."
  [])

;;;###autoload
(define-minor-mode inhibit-mouse-mode
  "Disable all mouse input."
  :global t
  :lighter inhibit-mouse-mode-lighter
  :group 'inhibit-mouse
  (if inhibit-mouse-mode
      ;; ENABLE: inhibit-mouse-mode
      (progn
        (when inhibit-mouse-adjust-mouse-highlight
          (setq inhibit-mouse--backup-mouse-highlight mouse-highlight)
          (setq mouse-highlight nil))

        (when inhibit-mouse-adjust-show-help-function
          (setq inhibit-mouse--backup-show-help-function show-help-function)
          (setq show-help-function nil))

        (setq inhibit-mouse--ignored-events nil)

        (dolist (modifiers (append (list nil) inhibit-mouse-key-modifiers))
          (dolist (base inhibit-mouse-misc-events)
            (inhibit-mouse--define-input-event
             modifiers
             (intern base)
             #'inhibit-mouse--default-mouse-event))

          (dolist (multiplier (cons nil inhibit-mouse-multipliers))
            (dolist (button inhibit-mouse-button-numbers)
              (dolist (event inhibit-mouse-button-events)
                (let ((base (format "%s%s-%d"
                                    (if multiplier
                                        (concat multiplier "-")
                                      "")
                                    event
                                    button)))
                  (inhibit-mouse--define-input-event
                   modifiers
                   (intern base)
                   #'inhibit-mouse--default-mouse-event)))))))
    ;; DISABLE: inhibit-mouse-mode
    (when inhibit-mouse-adjust-mouse-highlight
      (setq mouse-highlight inhibit-mouse--backup-mouse-highlight))

    (when inhibit-mouse-adjust-show-help-function
      (setq show-help-function inhibit-mouse--backup-show-help-function))

    (dolist (ignored-event inhibit-mouse--ignored-events)
      (let ((modifier (car ignored-event))
            (base (cdr ignored-event)))
        ;; Remove the ignored events when disabling the mode
        (inhibit-mouse--define-input-event modifier base nil)))

    ;; Clear the list after restoring
    (setq inhibit-mouse--ignored-events nil)))

(provide 'inhibit-mouse)
;;; inhibit-mouse.el ends here
