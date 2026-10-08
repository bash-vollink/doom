;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; Reopen the GUI frame where it was last closed, at the same size (or
;; maximized/fullscreen if it was). Saved on quit to Doom's cache dir.
(defvar my/frame-geometry-file (concat doom-cache-dir "frame-geometry.el"))

(defun my/save-frame-geometry ()
  "Write the selected frame's position, size and fullscreen state."
  (when (display-graphic-p)
    (let ((frame (selected-frame)))
      (with-temp-file my/frame-geometry-file
        (prin1 (list :position (frame-position frame)
                     :width (frame-text-width frame)
                     :height (frame-text-height frame)
                     :fullscreen (frame-parameter frame 'fullscreen))
               (current-buffer))))))

(defun my/restore-frame-geometry ()
  "Apply the geometry saved by `my/save-frame-geometry', if any."
  (when (and (display-graphic-p) (file-readable-p my/frame-geometry-file))
    (let ((geometry (with-temp-buffer
                      (insert-file-contents my/frame-geometry-file)
                      (read (current-buffer))))
          (frame (selected-frame)))
      (set-frame-size frame (plist-get geometry :width)
                      (plist-get geometry :height) t)
      (set-frame-position frame
                          (car (plist-get geometry :position))
                          (cdr (plist-get geometry :position)))
      (when (plist-get geometry :fullscreen)
        (set-frame-parameter frame 'fullscreen
                             (plist-get geometry :fullscreen))))))

(add-hook 'kill-emacs-hook #'my/save-frame-geometry)
(add-hook 'window-setup-hook #'my/restore-frame-geometry)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Every .org file in `org-directory' (todo.org, birthdays.org, ...) feeds the
;; agenda, so new files show up without being registered here.
(setq org-agenda-files (list org-directory))

(defun my/org-capture-birthday-template ()
  "Ask for a name and date, return a yearly-repeating birthday entry."
  (let* ((name (read-string "Name: "))
         (date (org-read-date nil t nil (format "%s's birthday: " name))))
    (format "* %s's Birthday\n<%s +1y>\n%%?"
            name (format-time-string "%Y-%m-%d %a" date))))

(after! org
  ;; SPC X <key>. Replaces Doom's defaults so captured items look like the
  ;; rest of todo.org (TODO headings, not [ ] checkboxes).
  (setq org-capture-templates
        '(;; Quick task into Inbox; refile it later with SPC m r r
          ("t" "Task" entry
           (file+headline "todo.org" "Inbox")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:"
           :empty-lines 1)
          ;; Same, plus a link back to the file/heading you were in
          ("T" "Task with link" entry
           (file+headline "todo.org" "Inbox")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a"
           :empty-lines 1)
          ;; Scheduled work task, filed directly
          ("w" "Work task" entry
           (file+olp "todo.org" "Work" "Tasks")
           "* TODO %?\nSCHEDULED: %^t"
           :empty-lines 1)
          ;; One-off meeting with a date and time
          ("m" "Meeting" entry
           (file+olp "todo.org" "Work" "Meetings")
           "* %?\n%^T"
           :empty-lines 1)
          ;; Trip packing checklist; edit the list in templates/packing.org
          ("p" "Packing list" entry
           (file+olp "todo.org" "Personal" "Tasks")
           (file "templates/packing.org")
           :empty-lines 1)
          ;; Birthday into birthdays.org
          ("b" "Birthday" entry
           (file "birthdays.org")
           (function my/org-capture-birthday-template)
           :empty-lines-before 1)))

  ;; SPC m r r offers only todo.org headings (Inbox, Work/Tasks,
  ;; Personal/Tasks, ...), not birthdays.org.
  (setq org-refile-targets
        `((,(expand-file-name "todo.org" org-directory) :maxlevel . 2))))

(after! org
  ;; SPC m A moves a finished subtree to archive/<file>_archive, filed under a
  ;; year/month/day tree, instead of keeping "Completed Tasks" sections.
  (setq org-archive-location "archive/%s_archive::datetree/")

  ;; Record when things close and why they slip, in a folded LOGBOOK drawer.
  ;; Rescheduling prompts for a reason.
  (setq org-log-done 'time
        org-log-into-drawer t
        org-log-reschedule 'note)

  ;; NEXT = doing now, WAIT = blocked on someone/something (asks why),
  ;; CANX = dropped (asks why).
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d)" "CANX(c@)"))
        org-todo-keyword-faces
        '(("NEXT" . +org-todo-active)
          ("WAIT" . +org-todo-onhold)
          ("CANX" . +org-todo-cancel))))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
