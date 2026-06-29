;; ╔══════════════════════════════════════════════════════════════════════╗
;; ║   EMACS CONFIG — FINAL v8.7  (Universal · Termux · Desktop)          ║
;; ║   VS Code Edition: Flutter Widget Tree Guides · Rainbow · Powerline  ║
;; ║                                                                        ║
;; ║   Changelog v8.3 — Flutter Widget Tree Guides (VS Code style):        ║
;; ║     [NEW] §10-B-2 my/dart-guide--render: renderer Dart-specific       ║
;; ║           menghasilkan ├──, └──, │, // WidgetName persis seperti      ║
;; ║           VS Code Flutter extension. Bekerja tanpa LSP, tanpa         ║
;; ║           plugin MELPA, di Termux terminal maupun GUI.                ║
;; ║           Algoritma flat scan O(n): tiap widget opener dicari         ║
;; ║           close-line, child-indent, named params → overlay.           ║
;; ║     [NEW] my/ui-guide-update: mode-aware dispatch —                   ║
;; ║           dart-mode → my/dart-guide--render (widget tree),            ║
;; ║           lainnya → my/ui-guide--render (generic indent guide)        ║
;; ║     [NEW] my/ui-guide--place-ov: shared placer gantikan dua fungsi    ║
;; ║           terpisah; defalias my/ui-guide--add-overlay untuk compat    ║
;; ║                                                                        ║
;; ║   Changelog v8.2 — FIX: Flutter UI Guides di Termux:                 ║
;; ║     [FIX] my/ui-guide--add-overlay: (looking-at "\s-") salah —       ║
;; ║           "\s-" di Emacs Lisp = spasi+tanda-hubung (" -"), bukan     ║
;; ║           whitespace. Diganti (looking-at "\\s-") → \s- yang benar   ║
;; ║     [FIX] EOL overlay: before-string agar newline tidak hilang        ║
;; ║     [FIX] lsp-after-open-hook gantikan lsp-mode-hook agar            ║
;; ║           my/ensure-flutter-widget-guides berjalan setelah LSP ready  ║
;; ║     [FIX] UTF-8 detection: cek LANG+LC_ALL+LC_CTYPE+LC_MESSAGES      ║
;; ║     [OPT] require cl-lib lebih awal untuk cl-some                     ║
;; ║                                                                        ║
;; ║   Changelog v8.1:                                                      ║
;; ║     [FIX] my/ui-guide--build-tree: setcar cddr — koreksi last-child   ║
;; ║     [FIX] my/update-disk-cache: regex group \\(\\S-+\\)               ║
;; ║     [REF] highlight-indent-guides/company-quickhelp/lsp-dart ke :custom║
;; ║     [OPT] global-auto-revert-mode + recentf-mode                      ║
;; ╚══════════════════════════════════════════════════════════════════════╝

;; ════════════════════════════════════════════════════════════════════════
;; §0  DETEKSI ENVIRONMENT — PALING AWAL
;; ════════════════════════════════════════════════════════════════════════

(defvar my/is-termux
  (or (getenv "TERMUX_VERSION")
      (file-exists-p "/data/data/com.termux"))
  "Non-nil jika berjalan di Android Termux.")

(defvar my/is-gui (display-graphic-p)
  "Non-nil jika berjalan di GUI Emacs (bukan terminal).")

(defvar my/is-desktop
  (and (not my/is-termux)
       (or my/is-gui
           (memq system-type '(gnu/linux darwin windows-nt))))
  "Non-nil jika berjalan di desktop/laptop.")

(defvar my/is-emacs29+
  (>= emacs-major-version 29)
  "Non-nil jika Emacs versi 29 ke atas (dukungan treesit bawaan).")

;; ════════════════════════════════════════════════════════════════════════
;; §1  EARLY INIT — GC threshold TERBATAS
;; ════════════════════════════════════════════════════════════════════════

(setq gc-cons-threshold
      (if my/is-termux
          (* 64 1024 1024)
        (* 256 1024 1024)))

(setq gc-cons-percentage 0.6)

;; ════════════════════════════════════════════════════════════════════════
;; §2  PACKAGE MANAGER
;; ════════════════════════════════════════════════════════════════════════

(require 'package)
(require 'cl-lib)

;; [FIX] gnutls hanya diatur untuk Termux (pakai HTTP) — desktop tidak perlu
(when my/is-termux
  (setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3"))

(setq package-archives
      (if my/is-termux
          '(("melpa"  . "http://melpa.org/packages/")
            ("gnu"    . "http://elpa.gnu.org/packages/")
            ("nongnu" . "http://elpa.nongnu.org/packages/"))
        '(("melpa"  . "https://melpa.org/packages/")
          ("gnu"    . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/packages/"))))

(setq package-enable-at-startup nil)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

(setq use-package-always-ensure t)
(setq use-package-expand-minimally t)
(setq use-package-verbose nil)

;; ════════════════════════════════════════════════════════════════════════
;; §3  GCMH — Garbage Collector Magic Hack
;; ════════════════════════════════════════════════════════════════════════

(use-package gcmh
  :demand t
  :custom
  (gcmh-high-cons-threshold
   (if my/is-termux (* 32 1024 1024) (* 128 1024 1024)))
  (gcmh-low-cons-threshold (* 2 1024 1024))
  (gcmh-idle-delay (if my/is-termux 8 15))
  (gcmh-verbose nil)
  :config
  (gcmh-mode 1))

;; ════════════════════════════════════════════════════════════════════════
;; §4  BYTE-COMPILATION OTOMATIS
;; ════════════════════════════════════════════════════════════════════════

(defun my/byte-compile-on-save ()
  "Byte-compile file .el saat disimpan — selalu, tidak perlu .elc dulu ada."
  (when (and buffer-file-name
             (string-suffix-p ".el" buffer-file-name)
             (not (string-match-p "\\(-autoloads\\|-pkg\\|-test\\)\\.el$"
                                  buffer-file-name))
             (not (string-suffix-p ".dir-locals.el" buffer-file-name)))
    (with-demoted-errors "[NZR byte-compile on-save] %s"
      (byte-compile-file buffer-file-name)
      (message "[NZR] Compiled %s.elc"
               (file-name-nondirectory buffer-file-name)))))

(add-hook 'after-save-hook #'my/byte-compile-on-save)

(defun my/byte-compile-init-on-save ()
  "Byte-compile user-init-file saat disimpan.
[FIX v8.7] pakai user-init-file bukan hardcode ~/.emacs."
  (when (and buffer-file-name user-init-file
             (string= (expand-file-name buffer-file-name)
                      (expand-file-name user-init-file)))
    (with-demoted-errors "[NZR init-compile] %s"
      (byte-compile-file buffer-file-name)
      (message "[NZR] Init ter-byte-compile: %s"
               (file-name-nondirectory buffer-file-name)))))

(add-hook 'after-save-hook #'my/byte-compile-init-on-save)

(defvar my/byte-compile-blacklist
  '("org" "org-modern" "yasnippet" "yasnippet-snippets")
  "Daftar nama paket yang dilewati saat idle byte-compile.")

(defun my/idle-byte-compile-packages ()
  "Byte-compile semua file .el yang belum punya .elc.
[FIX v8.7 #1] Sync path kini pakai directory-files-RECURSIVELY.
[FIX v8.7 #2] Juga compile user-init-file jika .elc usang/tidak ada."
  ;; Compile init file jika perlu
  (when user-init-file
    (let* ((src (expand-file-name user-init-file))
           (elc (concat src ".elc")))
      (when (and (file-exists-p src)
                 (or (not (file-exists-p elc))
                     (file-newer-than-file-p src elc)))
        (with-demoted-errors "[NZR init-compile idle] %s"
          (byte-compile-file src)))))
  ;; Compile direktori paket
  (let ((dirs (delq nil (list package-user-dir
                              (let ((d (expand-file-name "lisp/" user-emacs-directory)))
                                (and (file-directory-p d) d))))))
    (if (fboundp 'async-start)
        (async-start
         `(lambda ()
            (require 'bytecomp)
            (dolist (dir ',dirs)
              (when (file-directory-p dir)
                (dolist (el-file (directory-files-recursively dir "\\.el$"))
                  (let* ((elc   (concat el-file "c"))
                         (pname (file-name-nondirectory
                                 (directory-file-name
                                  (file-name-directory el-file))))
                         (skip  (or (string-suffix-p ".dir-locals.el" el-file)
                                    (string-match-p
                                     "\\(-pkg\\|-autoloads\\|-test\\)\\.el$"
                                     el-file)
                                    (member pname ',my/byte-compile-blacklist))))
                    (when (and (not (file-exists-p elc)) (not skip))
                      (ignore-errors (byte-compile-file el-file))))))))
         (lambda (_) (message "[NZR] Async byte-compile selesai ✓")))
      ;; Sync fallback (Termux / tanpa async.el)
      (let ((n 0))
        (dolist (dir dirs)
          (when (file-directory-p dir)
            ;; [FIX] directory-files-recursively bukan directory-files biasa
            (dolist (el-file (directory-files-recursively dir "\\.el$"))
              (let* ((elc   (concat el-file "c"))
                     (pname (file-name-nondirectory
                             (directory-file-name
                              (file-name-directory el-file))))
                     (skip  (or (string-suffix-p ".dir-locals.el" el-file)
                                (string-match-p
                                 "\\(-pkg\\|-autoloads\\|-test\\)\\.el$"
                                 el-file)
                                (member pname my/byte-compile-blacklist))))
                (when (and (not (file-exists-p elc)) (not skip))
                  (with-demoted-errors "[NZR byte-compile] %s"
                    (byte-compile-file el-file)
                    (setq n (1+ n))))))))
        (when (> n 0)
          (message "[NZR] Byte-compiled %d file(s) ✓" n))))))

;; [FIX v8.7] nil → t agar timer berulang, bukan hanya sekali seumur hidup
(run-with-idle-timer  30 nil #'my/idle-byte-compile-packages) ; pertama kali
(run-with-idle-timer 120 t   #'my/idle-byte-compile-packages) ; berkala tiap 120 dtk

;; Compile manual: M-x my/byte-compile-all
(defun my/byte-compile-all ()
  "Compile semua .el secara manual — gunakan setelah install/update paket."
  (interactive)
  (message "[NZR] Memulai byte-compile semua paket...")
  (my/idle-byte-compile-packages)
  (message "[NZR] Byte-compile selesai."))


;; ════════════════════════════════════════════════════════════════════════
;; §5  UI DASAR
;; ════════════════════════════════════════════════════════════════════════

(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq ring-bell-function 'ignore)

(setq-default cursor-type 'bar)
(blink-cursor-mode t)
(setq scroll-step 1)
(setq scroll-conservatively 101)
(setq scroll-margin 2)

(global-display-line-numbers-mode t)
(global-font-lock-mode t)
(show-paren-mode t)
(electric-indent-mode t)
(global-visual-line-mode t)
(global-auto-revert-mode t)            ; auto-refresh buffer jika file berubah di disk
(recentf-mode t)                       ; aktifkan daftar file yang baru dibuka
(setq recentf-max-menu-items 25
      recentf-max-saved-items 50)
(global-set-key (kbd "C-x C-r") 'recentf-open-files)
(setq-default tab-width 4)
(setq-default indent-tabs-mode nil)
(delete-selection-mode t)
(column-number-mode t)

(menu-bar-mode -1)
(when my/is-gui
  (tool-bar-mode   -1)
  (scroll-bar-mode -1)
  (tooltip-mode    -1))

(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
(setq backup-by-copying t)
(setq version-control t)
(setq kept-new-versions 5)
(setq kept-old-versions 2)
(setq delete-old-versions t)
(make-directory (expand-file-name "backups/"   user-emacs-directory) t)

(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t)))
(make-directory (expand-file-name "auto-save/" user-emacs-directory) t)

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)

;; ════════════════════════════════════════════════════════════════════════
;; §6  THEME & WARNA
;; ════════════════════════════════════════════════════════════════════════

(set-face-background 'default "#000000")
(set-face-foreground 'default "#e0e0e0")
(load-theme 'wombat t)

;; ════════════════════════════════════════════════════════════════════════
;; §7  SHARED RAINBOW PALETTE
;; ════════════════════════════════════════════════════════════════════════

(defvar my/palette-normal
  '("#3d0000" "#3d1a00" "#2d2d00" "#003d00"
    "#003d3d" "#00003d" "#1a003d" "#3d0033")
  "Warna gelap per kedalaman 1-8.")

(defvar my/palette-active
  '("#ff3333" "#ff8800" "#ffee00" "#00ff44"
    "#00ffee" "#4488ff" "#bb44ff" "#ff44cc")
  "Warna terang per kedalaman 1-8.")

(defun my/palette-get (depth &optional active)
  "Kembalikan warna hex untuk DEPTH (integer, 1-based)."
  (let ((palette (if active my/palette-active my/palette-normal)))
    (nth (mod (1- (max 1 depth)) (length palette)) palette)))

;; ════════════════════════════════════════════════════════════════════════
;; §8  PLUGINS
;; ════════════════════════════════════════════════════════════════════════

;; ── UNDO/REDO ─────────────────────────────────────────────────────────
(use-package undo-fu
  :defer t
  :bind (("C-z"   . undo-fu-only-undo)
         ("C-S-z" . undo-fu-only-redo)
         ("C-/"   . undo-fu-only-undo)
         ("C-?"   . undo-fu-only-redo)))

;; ── WHICH-KEY ─────────────────────────────────────────────────────────
(use-package which-key
  :defer 1
  :custom
  (which-key-idle-delay 0.5)
  (which-key-popup-type 'side-window)
  (which-key-side-window-location 'bottom)
  (which-key-side-window-max-height 0.3)
  (which-key-min-display-lines 5)
  (which-key-max-display-columns 3)
  :config
  (which-key-mode t)
  (set-face-attribute 'which-key-key-face nil
    :foreground "#00ff00" :weight 'bold :background "#0a1a0a")
  (set-face-attribute 'which-key-command-description-face nil
    :foreground "#e0e0e0" :background "#0a1a0a")
  (set-face-attribute 'which-key-group-description-face nil
    :foreground "#00cc00" :weight 'bold :background "#0a1a0a")
  (set-face-attribute 'which-key-separator-face nil
    :foreground "#008800" :background "#0a1a0a")
  (set-face-attribute 'which-key-local-map-description-face nil
    :foreground "#88ff88" :background "#0a1a0a"))

;; ── HIGHLIGHT INDENT GUIDES ────────────────────────────────────────────
(use-package highlight-indent-guides
  :ensure t
  :demand t
  :custom
  (highlight-indent-guides-auto-enabled t)
  (highlight-indent-guides-method 'column)
  (highlight-indent-guides-responsive 'top)
  (highlight-indent-guides-delay 0)
  :config
  (defun my/indent-guide-highlighter (level responsive display)
    "Rainbow highlighter menggunakan shared palette dari §7."
    (let ((color (my/palette-get level (eq responsive 'top))))
      (list :background color :foreground color)))

  (setq highlight-indent-guides-highlighter-function
        #'my/indent-guide-highlighter)

  (add-hook 'prog-mode-hook #'highlight-indent-guides-mode)

  (dolist (mode '(mhtml-mode html-mode  css-mode   scss-mode
                  web-mode   yaml-mode  json-mode  conf-mode
                  sh-mode    dockerfile-mode nxml-mode sgml-mode
                  js-mode    js2-mode   dart-mode))
    (add-hook (intern (concat (symbol-name mode) "-hook"))
              #'highlight-indent-guides-mode))

  (defun my/maybe-indent-guides ()
    "Aktifkan indent-guides dengan guard keamanan penuh."
    (when (and (fboundp 'highlight-indent-guides-mode)
               buffer-file-name
               (not (minibufferp))
               (not (string-prefix-p " " (buffer-name)))
               (not (string-prefix-p "*" (buffer-name))))
      (highlight-indent-guides-mode 1)))

  (add-hook 'after-change-major-mode-hook #'my/maybe-indent-guides)
  (my/maybe-indent-guides))

;; ── YASNIPPET ─────────────────────────────────────────────────────────
(use-package yasnippet
  :defer t
  :hook ((prog-mode  . yas-minor-mode)
         (html-mode  . yas-minor-mode)
         (mhtml-mode . yas-minor-mode)
         (css-mode   . yas-minor-mode)
         (sh-mode    . yas-minor-mode)
         (dart-mode  . yas-minor-mode))
  :custom
  (yas-snippet-dirs '("~/.emacs.d/snippets"))
  :config
  (make-directory "~/.emacs.d/snippets" t)
  (yas-reload-all)
  (define-key yas-minor-mode-map (kbd "TAB")   'yas-expand)
  (define-key yas-minor-mode-map (kbd "<tab>") 'yas-expand))

(use-package yasnippet-snippets
  :defer t
  :after yasnippet)

;; ── ORG-MODE ──────────────────────────────────────────────────────────
(use-package org
  :defer t
  :mode ("\\.org\\'" . org-mode)
  :custom
  (org-startup-indented t)
  (org-hide-leading-stars t)
  (org-ellipsis " ▼")
  (org-pretty-entities t)
  :config
  (setq org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "WAITING" "DONE"))
        org-todo-keyword-faces
        '(("TODO"        . (:foreground "#e94560" :weight bold))
          ("IN-PROGRESS" . (:foreground "#5599ff" :weight bold))
          ("WAITING"     . (:foreground "#cc88ff" :weight bold))
          ("DONE"        . (:foreground "#00ff00" :weight bold))))
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)))

(use-package org-modern
  :defer t
  :after org
  :hook (org-mode . org-modern-mode)
  :custom
  (org-modern-star  '("◉" "○" "✸" "✿"))
  (org-modern-todo  t)
  (org-modern-table t))

;; ── FLYCHECK ──────────────────────────────────────────────────────────
(use-package flycheck
  :defer t
  :hook ((prog-mode  . flycheck-mode)
         (sh-mode    . flycheck-mode)
         (html-mode  . flycheck-mode)
         (mhtml-mode . flycheck-mode)
         (css-mode   . flycheck-mode)
         (dart-mode  . flycheck-mode))
  :custom
  (flycheck-check-syntax-automatically '(mode-enabled save))
  (flycheck-display-errors-delay 0.5)
  :config
  (set-face-attribute 'flycheck-error nil
    :underline '(:color "#e94560" :style wave))
  (set-face-attribute 'flycheck-warning nil
    :underline '(:color "#ffaa00" :style wave))
  (set-face-attribute 'flycheck-info nil
    :underline '(:color "#5599ff" :style wave)))

;; ── COMPANY (AUTOCOMPLETE) ────────────────────────────────────────────
(use-package company
  :defer t
  :hook ((prog-mode  . company-mode)
         (sh-mode    . company-mode)
         (html-mode  . company-mode)
         (mhtml-mode . company-mode)
         (css-mode   . company-mode)
         (dart-mode  . company-mode))
  :custom
  (company-idle-delay 0.2)
  (company-minimum-prefix-length 1)
  (company-tooltip-limit 10)
  (company-tooltip-align-annotations t)
  (company-show-quick-access t)
  (company-selection-wrap-around t)
  :config
  (define-key company-active-map (kbd "<right>")  'company-complete-selection)
  (define-key company-active-map (kbd "RET")      nil)
  (define-key company-active-map (kbd "<return>") nil)
  (define-key company-active-map (kbd "<escape>") 'company-abort)
  (define-key company-active-map (kbd "<up>")     'company-select-previous)
  (define-key company-active-map (kbd "<down>")   'company-select-next)
  (define-key company-active-map (kbd "TAB")      'company-complete-common))

(use-package company-quickhelp
  :defer t
  :after company
  :if my/is-gui
  :custom
  (company-quickhelp-delay 0.5)
  :config
  (company-quickhelp-mode t))

;; ════════════════════════════════════════════════════════════════════════
;; §9  BRACKET PAIR COLORIZER
;; ════════════════════════════════════════════════════════════════════════

(use-package rainbow-delimiters
  :demand t
  :hook
  ((prog-mode  . rainbow-delimiters-mode)
   (dart-mode  . rainbow-delimiters-mode)
   (html-mode  . rainbow-delimiters-mode)
   (mhtml-mode . rainbow-delimiters-mode)
   (css-mode   . rainbow-delimiters-mode)
   (yaml-mode  . rainbow-delimiters-mode)
   (json-mode  . rainbow-delimiters-mode)
   (sh-mode    . rainbow-delimiters-mode))
  :config
  (let ((depths '(1 2 3 4 5 6 7 8 9)))
    (dolist (d depths)
      (set-face-foreground
       (intern (format "rainbow-delimiters-depth-%d-face" d))
       (my/palette-get d t))
      (set-face-attribute
       (intern (format "rainbow-delimiters-depth-%d-face" d))
       nil :weight 'bold)))

  (set-face-attribute 'rainbow-delimiters-unmatched-face nil
    :foreground "#ff0000"
    :background "#330000"
    :weight     'bold
    :underline  '(:color "#ff0000" :style wave))

  (set-face-attribute 'rainbow-delimiters-mismatched-face nil
    :foreground "#ff4400"
    :background "#2a1000"
    :weight     'bold
    :underline  '(:color "#ff4400" :style wave))

  (defun my/maybe-rainbow-delimiters ()
    "Aktifkan rainbow-delimiters di buffer kode yang sudah terbuka."
    (when (and (fboundp 'rainbow-delimiters-mode)
               buffer-file-name
               (not (minibufferp))
               (not (string-prefix-p "*" (buffer-name))))
      (rainbow-delimiters-mode 1)))

  (add-hook 'after-change-major-mode-hook #'my/maybe-rainbow-delimiters)
  (my/maybe-rainbow-delimiters))


;; ╔══════════════════════════════════════════════════════════════════════╗
;; ║   UNIVERSAL UI GUIDES — Garis Visual untuk SEMUA File               ║
;; ║   Works on: .dart .html .js .py .css .json .yaml .el .sh ...       ║
;; ╚══════════════════════════════════════════════════════════════════════╝

;; ════════════════════════════════════════════════════════════════════════
;; §10 FLUTTER / DART + UI GUIDES (VS Code Edition v8.0 — REFACTORED)
;; ════════════════════════════════════════════════════════════════════════

;; ── DART MODE ─────────────────────────────────────────────────────────
(use-package dart-mode
  :ensure t
  ;; Tidak pakai :defer t — dart-mode harus siap saat .dart file dibuka
  :mode ("\\.dart\\'" . dart-mode)
  :custom
  (dart-format-on-save t)
  :config
  (setq dart-sdk-path
        (or (getenv "DART_SDK")
            (when (executable-find "dart")
              (let ((candidate (expand-file-name
                               "../cache/dart-sdk"
                               (file-name-directory (executable-find "dart")))))
                (when (file-directory-p candidate) candidate)))
            (let ((candidate (expand-file-name "~/flutter/bin/cache/dart-sdk/")))
              (when (file-directory-p candidate) candidate))
            (let ((candidate "/usr/lib/dart/"))
              (when (file-directory-p candidate) candidate))
            nil)))

;; Fallback eksplisit: jika dart-mode gagal load, .dart tetap buka
;; di prog-mode (bukan fundamental-mode) sehingga hooks tetap terpicu
(with-eval-after-load 'dart-mode
  (add-to-list 'auto-mode-alist '("\\.dart\\'" . dart-mode)))
(unless (fboundp 'dart-mode)
  (add-to-list 'auto-mode-alist '("\\.dart\\'" . prog-mode)))

;; ── LSP MODE ──────────────────────────────────────────────────────────
(use-package lsp-mode
  :ensure t
  :defer t
  :commands (lsp lsp-deferred)
  :hook ((dart-mode . (lambda ()
                        ;; [FIX v8.5] Hanya mulai LSP jika Dart/Flutter SDK
                        ;; ditemukan di PATH. Mencegah error "Unable to find
                        ;; installed server" di Termux tanpa Dart SDK.
                        ;; Guides Elisp (my/dart-guide--render) tetap berjalan
                        ;; tanpa LSP — tidak perlu Dart SDK sama sekali.
                        (when (or (executable-find "dart")
                                  (executable-find "flutter")
                                  (and (boundp 'dart-sdk-path)
                                       (stringp dart-sdk-path)
                                       (file-directory-p dart-sdk-path)))
                          (lsp-deferred)))))
  :init
  (setq lsp-keymap-prefix "C-c l")
  :custom
  (lsp-idle-delay 0.3)
  (lsp-log-io nil)
  (lsp-enable-snippet t)
  (lsp-completion-provider :capf)
  (lsp-auto-install nil)
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-semantic-tokens-enable t))

;; ── LSP-UI ────────────────────────────────────────────────────────────
(use-package lsp-ui
  :ensure t
  :defer t
  :after lsp-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-sideline-enable t)
  (lsp-ui-sideline-show-diagnostics t)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-sideline-delay 0.3)
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-position 'at-point)
  (lsp-ui-doc-delay 0.5)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-doc-show-with-mouse t)
  (lsp-ui-peek-enable t)
  (lsp-ui-peek-always-show t)
  :config
  (when (fboundp 'set-face-attribute)
    (set-face-attribute 'lsp-ui-doc-background nil :background "#0d1117")
    (set-face-attribute 'lsp-ui-doc-header nil
      :background "#1a1a2e" :foreground "#e0e0e0" :weight 'bold)))

;; ── TREEMACS ──────────────────────────────────────────────────────────
(use-package treemacs
  :ensure t
  :defer t
  :commands (treemacs)
  :custom
  (treemacs-is-never-other-window t)
  (treemacs-space-between-root-nodes nil)
  (treemacs-indentation 2)
  (treemacs-width 30))

(use-package lsp-treemacs
  :ensure t
  :defer t
  :after (lsp-mode treemacs)
  :config
  (lsp-treemacs-sync-mode 1))

;; ════════════════════════════════════════════════════════════════════════
;; §10-A  FLUTTER UI GUIDES (lsp-dart) — .dart di Flutter Project
;; ════════════════════════════════════════════════════════════════════════

(use-package lsp-dart
  :ensure t
  :defer t
  :after (lsp-mode dart-mode)
  :init
  (setq lsp-dart-flutter-sdk-dir
        (or (getenv "FLUTTER_ROOT")
            (when (executable-find "flutter")
              (let ((candidate (expand-file-name
                               "../.."
                               (file-name-directory (executable-find "flutter")))))
                (when (file-directory-p candidate) candidate)))
            (let ((candidate (expand-file-name "~/flutter/")))
              (when (file-directory-p candidate) candidate))
            nil))
  :custom
  (lsp-dart-outline t)
  (lsp-dart-flutter-outline t)
  (lsp-dart-flutter-widget-guides t)
  (lsp-dart-test-code-lens t)
  (lsp-dart-closing-labels t)
  (lsp-dart-closing-labels-prefix " ")
  :config
  ;; Pastikan widget guides mode aktif
  (defun my/ensure-flutter-widget-guides ()
    "Pastikan Flutter UI Guides aktif di buffer dart."
    (when (and (eq major-mode 'dart-mode)
               (bound-and-true-p lsp-mode))
      (when (and (fboundp 'lsp-dart-flutter-widget-guides-mode)
                 (not lsp-dart-flutter-widget-guides-mode))
        (lsp-dart-flutter-widget-guides-mode 1))
      (when (and (fboundp 'lsp-dart-flutter-outline-mode)
                 (not lsp-dart-flutter-outline-mode))
        (lsp-dart-flutter-outline-mode 1))
      (when (and (fboundp 'lsp-dart-closing-labels-mode)
                 (not lsp-dart-closing-labels-mode))
        (lsp-dart-closing-labels-mode 1))))

  (add-hook 'dart-mode-hook      #'my/ensure-flutter-widget-guides)
  (add-hook 'lsp-after-open-hook #'my/ensure-flutter-widget-guides)

  ;; Auto-open Flutter Outline
  (defun my/flutter-outline-auto-open ()
    "Auto-open Flutter Outline saat buka file .dart."
    (when (and (eq major-mode 'dart-mode)
               (bound-and-true-p lsp-mode))
      (run-with-timer 2 nil
                      (lambda (buf)
                        (when (buffer-live-p buf)
                          (with-current-buffer buf
                            (when (fboundp 'lsp-dart-show-flutter-outline)
                              (lsp-dart-show-flutter-outline t)))))
                      (current-buffer))))
  (add-hook 'dart-mode-hook #'my/flutter-outline-auto-open)

  ;; Closing Labels — face styling
  (when (facep 'lsp-dart-closing-label-face)
    (set-face-attribute 'lsp-dart-closing-label-face nil
      :foreground "#00cc66" :slant 'italic :height 0.85)))

;; ── flutter.el ────────────────────────────────────────────────────────
(use-package flutter
  :ensure t
  :defer t
  :after dart-mode
  :config
  (setq flutter-sdk-path
        (or (getenv "FLUTTER_HOME")
            (when (executable-find "flutter")
              (let ((candidate (expand-file-name
                               "../.."
                               (file-name-directory (executable-find "flutter")))))
                (when (file-directory-p candidate) candidate)))
            (let ((candidate (expand-file-name "~/flutter/")))
              (when (file-directory-p candidate) candidate))
            nil)))

;; ── Flutter helper functions ──────────────────────────────────────────
(defun my/flutter-outline-toggle ()
  "Toggle Flutter/Dart Outline panel. Binding: F8."
  (interactive)
  (cond
   ((fboundp 'lsp-dart-show-flutter-outline)
    (lsp-dart-show-flutter-outline))
   ((fboundp 'lsp-dart-show-outline)
    (lsp-dart-show-outline))
   (t (message "[NZR] lsp-dart belum aktif. Pastikan buka file .dart lebih dulu."))))

(defun my/flutter-hot-reload ()
  "Flutter hot reload. Binding: F9."
  (interactive)
  (if (fboundp 'flutter-hot-reload)
      (flutter-hot-reload)
    (message "[NZR] flutter package belum load.")))

(defun my/flutter-hot-restart ()
  "Flutter hot restart. Binding: S-F9."
  (interactive)
  (if (fboundp 'flutter-hot-restart)
      (flutter-hot-restart)
    (message "[NZR] flutter package belum load.")))

;; ════════════════════════════════════════════════════════════════════════
;; §10-B  UNIVERSAL UI GUIDES (Indentasi) — SEMUA File
;; ════════════════════════════════════════════════════════════════════════
;;
;;  ARSITEKTUR v8.0 — Tiga tier fallback:
;;  ┌─────────────────────────────────────────────────────────────────────┐
;;  │  Tier 1 (Emacs 29+ + treesit): Mengaktifkan treesit jika tersedia │
;;  │  untuk parsing indentasi via C core. Performa terbaik, minim      │
;;  │  blocking.                                                         │
;;  │                                                                    │
;;  │  Tier 2 (indent-bars package): Jika treesit tidak tersedia tapi    │
;;  │  Emacs 29+, gunakan paket indent-bars dari MELPA sebagai alternatif│
;;  │  modern berbasis overlay yang lebih efisien.                       │
;;  │                                                                    │
;;  │  Tier 3 (my/ui-guide Elisp murni): Fallback universal untuk semua  │
;;  │  versi Emacs. Portabilitas maksimal, tidak ada dependensi eksternal│
;;  └─────────────────────────────────────────────────────────────────────┘

(defvar my/ui-guide-use-treesit
  (and my/is-emacs29+ (fboundp 'treesit-available-p) (treesit-available-p))
  "Non-nil jika Tier 1 (treesit) tersedia dan aktif.")

(defvar my/ui-guide-use-indent-bars nil
  "Non-nil jika Tier 2 (indent-bars) diaktifkan sebagai fallback modern.")

;; ── Tier 1 & 2: Aktivasi treesit / indent-bars jika memenuhi syarat ──
(when my/ui-guide-use-treesit
  ;; Treesit aktif: gunakan indentasi bawaan treesit yang diproses di C core
  ;; Tidak perkan konfigurasi overlay manual — treesit menangani sendiri
  (setq treesit-font-lock-level 4)
  (message "[NZR] Tier 1: treesit aktif untuk UI Guides — C-core parsing"))

;; Tier 2: indent-bars — opsional, aktifkan jika ingin fallback modern
;; untuk Emacs 29+ tanpa treesit, atau sebagai preferensi pribadi.
;; Untuk mengaktifkan, install: M-x package-install RET indent-bars RET
;; lalu set my/ui-guide-use-indent-bars ke t di bawah ini.
;; (setq my/ui-guide-use-indent-bars nil)

(when (and my/is-emacs29+ (not my/ui-guide-use-treesit) my/ui-guide-use-indent-bars)
  (use-package indent-bars
    :ensure t
    :hook ((prog-mode yaml-mode json-mode) . indent-bars-mode)
    :custom
    (indent-bars-color '(highlight :face-bg t :blend 0.15))
    (indent-bars-pattern ".")
    (indent-bars-width-frac 0.2)
    (indent-bars-pad-frac 0.1)
    (indent-bars-zigzag nil)
    (indent-bars-color-by-depth 'palette)
    (indent-bars-highlight-current-depth 'underline)
    (indent-bars-display-on-gui t)
    (indent-bars-display-on-term t))
  (message "[NZR] Tier 2: indent-bars aktif — overlay modern MELPA"))

;; ── Tier 3: my/ui-guide — Fallback Universal Elisp Murni ──────────────
;; Tetap dipertahankan sebagai fondasi untuk kompatibilitas universal.
;; Aktif di semua versi Emacs, tidak memerlukan dependensi eksternal.

(defvar my/ui-guide-chars
  (if (or (display-graphic-p)
          (cl-some (lambda (var)
                     (let ((val (getenv var)))
                       (and val (string-match-p "utf-?8" (downcase val)))))
                   '("LANG" "LC_ALL" "LC_CTYPE" "LC_MESSAGES")))
      '((vertical   . "│")
        (horizontal . "─")
        (bottom     . "└")
        (middle     . "├")
        (space      . " "))
    '((vertical   . "|")
      (horizontal . "-")
      (bottom     . "L")
      (middle     . "|-")
      (space      . " ")))
  "Karakter UI Guides — Unicode jika terminal mendukung, ASCII fallback.")

(defface my/ui-guide-face
  '((t :foreground "#3a5a45" :background unspecified :weight normal))
  "Face untuk UI Guides — hijau abu-abu gelap untuk │ dan ├──.")

(defface my/ui-guide-active-face
  '((t :foreground "#5a8a6a" :background unspecified :weight bold))
  "Face untuk guide aktif — hijau abu-abu untuk └──.")

;; ── [REF] Fungsi UI Guides dengan (ignore-errors ...) idiomatic ───────

;; ── [v8.2+v8.3] Core overlay placer — dipakai KEDUA renderer ─────────
;;
;;  FIX v8.2 #1 : (looking-at "\\s-") — backslash ganda → regex \s-
;;                (whitespace class), BUKAN "\s-" = spasi literal + tanda hubung
;;  FIX v8.2 #2 : EOL pakai before-string agar newline tidak disembunyikan
;;  v8.3        : refactor jadi my/ui-guide--place-ov (shared oleh dart + generic)

(defun my/ui-guide--place-ov (line col str face)
  "Buat overlay di LINE/COL dengan STR menggunakan FACE.
v8.6 FIX: Setiap karakter dibuat overlay TERPISAH sehingga
box-drawing chars tepat tampil di Termux terminal.
Sebelumnya: 3-char display-property sering tidak ter-render."
  (let ((offset 0))
    (mapc
     (lambda (ch)
       (let ((s    (char-to-string ch))
             (col2 (+ col offset)))
         (ignore-errors
           (save-excursion
             (goto-char (point-min))
             (forward-line line)
             (move-to-column col2)
             (cond
              ((and (< (point) (line-end-position))
                    (looking-at "\\s-"))
               (let ((ov (make-overlay (point) (1+ (point)))))
                 (overlay-put ov 'category 'my/ui-guide)
                 (overlay-put ov 'display  (propertize s 'face face))
                 (overlay-put ov 'priority 200)))
              ((eolp)
               (let* ((pad (max 0 (- col2 (current-column))))
                      (ov  (make-overlay (point) (point))))
                 (overlay-put ov 'category      'my/ui-guide)
                 (overlay-put ov 'before-string
                              (propertize
                               (concat (make-string pad ?\s) s)
                               'face face))
                 (overlay-put ov 'priority 200))))))
         (setq offset (1+ offset))))
     (string-to-list str))))
;; Alias untuk kompatibilitas mundur (my/ui-guide--render masih pakai nama lama)
(defalias 'my/ui-guide--add-overlay #'my/ui-guide--place-ov)

(defun my/ui-guide-clear ()
  "Hapus semua UI Guides overlay."
  (ignore-errors
    (remove-overlays (point-min) (point-max) 'category 'my/ui-guide)))

(defun my/ui-guide--get-indent (line)
  "Ambil indentasi baris LINE. Return 0 jika error."
  (or (ignore-errors
        (save-excursion
          (goto-char (point-min))
          (forward-line line)
          (back-to-indentation)
          (current-column)))
      0))

(defun my/ui-guide--line-content (line)
  "Ambil konten baris LINE sebagai string. Return \"\" jika error."
  (or (ignore-errors
        (save-excursion
          (goto-char (point-min))
          (forward-line line)
          (string-trim (or (thing-at-point 'line t) ""))))
      ""))

(defun my/ui-guide--is-empty-line (line)
  "Cek apakah LINE kosong atau hanya whitespace."
  (let ((content (my/ui-guide--line-content line)))
    (or (string-empty-p content)
        (string-match-p "^\\s-*$" content))))

;; ROBUST: Build tree dengan validasi
(defun my/ui-guide--build-tree ()
  "Analisis indentasi, return tree. Hanya proses buffer dengan >1 baris."
  (let ((total-lines (count-lines (point-min) (point-max))))
    (if (< total-lines 2)
        '()
      (let ((guides '())
            (stack  '()))
        (dotimes (line total-lines)
          (let* ((indent  (my/ui-guide--get-indent line))
                 (content (my/ui-guide--line-content line))
                 (is-empty (my/ui-guide--is-empty-line line)))
            (unless (or is-empty (string-empty-p content))
              (while (and stack (>= (cdar stack) indent))
                (setq stack (cdr stack)))
              (when stack
                (let* ((parent       (caar stack))
                       (parent-indent (cdar stack))
                       (existing     (assoc parent guides)))
                  (if existing
                      (setcar (cddr existing) line)   ; update last-child di posisi ke-3
                    (push (list parent line line parent-indent) guides))))
              (push (cons line indent) stack))))
        guides))))

;; ROBUST: Render dengan validasi
(defun my/ui-guide--render (guides)
  "Gambar garis visual dengan safety."
  (my/ui-guide-clear)
  (when (and guides (listp guides))
    (let ((chars my/ui-guide-chars))
      (dolist (guide guides)
        (when (and (listp guide) (>= (length guide) 4))
          (let* ((parent-line   (nth 0 guide))
                 (child-end     (nth 2 guide))
                 (parent-indent (nth 3 guide))
                 (cursor-line   (1- (line-number-at-pos (point)))))
            (when (and (numberp parent-line) (numberp child-end)
                       (> child-end parent-line))
              (dotimes (line-num (- child-end parent-line))
                (let* ((current-line   (+ parent-line 1 line-num))
                       (current-indent (my/ui-guide--get-indent current-line))
                       (is-last        (= current-line child-end))
                       (char (cond
                              ((and is-last (= current-indent parent-indent))
                               (cdr (assoc 'bottom chars)))
                              ((= current-indent parent-indent)
                               (cdr (assoc 'middle chars)))
                              (t
                               (cdr (assoc 'vertical chars)))))
                       (face (if (= cursor-line parent-line)
                                 'my/ui-guide-active-face
                               'my/ui-guide-face)))
                  (my/ui-guide--add-overlay current-line parent-indent char face))))))))))

;; ════════════════════════════════════════════════════════════════════════
;; §10-B-2  DART FLUTTER WIDGET GUIDES — VS Code Style  (v8.3 NEW)
;; ════════════════════════════════════════════════════════════════════════
;;
;;  Renderer Dart-specific. Bekerja tanpa LSP, tanpa plugin MELPA.
;;  Aktif di semua Emacs versi, terminal (Termux) maupun GUI.
;;
;;  Output contoh:
;;    12    return MaterialApp(
;;    13      └──home: Scaffold(
;;    14         ├──appBar: AppBar(
;;    15         │  ├──title: const Text('Hello'),
;;    16         │  └──backgroundColor: Colors.blue, // AppBar
;;    17         └──body: const Text('World'),
;;    18      ), // Scaffold
;;    19    ); // MaterialApp
;;
;;  Algoritma (flat scan, satu pass):
;;    Untuk setiap baris yang merupakan widget opener (berakhir 'WidgetName('):
;;    1. Cari close-line → baris ')' setara indent
;;    2. Cari child-indent → indent anak pertama
;;    3. Kumpulkan named params → baris yang cocok pola 'name:'
;;    4. Gambar ├── (non-last) atau └── (last) di guide-col = child_indent - 3
;;    5. Gambar │ di guide-col untuk SEMUA baris antara non-last param & sibling-nya
;;    6. Tambah '// WidgetName' di close-line
;;    ⇒ Karena flat (bukan rekursif), setiap level diproses mandiri.
;;       Level luar menggambar │ yang "melewati" blok inner. ✓

;; ── Utility ──────────────────────────────────────────────────────────

(defun my/dart-guide--line-text (line)
  "Teks trimmed dari baris LINE (0-based). Return \"\" jika error."
  (or (ignore-errors
        (save-excursion
          (goto-char (point-min))
          (forward-line line)
          (string-trim
           (buffer-substring-no-properties
            (line-beginning-position) (line-end-position)))))
      ""))

(defun my/dart-guide--is-opener (line)
  "Non-nil jika LINE adalah widget constructor opener.
Pola: ada nama CamelCase diikuti '(' di akhir baris."
  (string-match-p "[A-Z][A-Za-z0-9_]*(\\s-*$"
                  (my/dart-guide--line-text line)))

(defun my/dart-guide--widget-name (line)
  "Ekstrak nama widget CamelCase terakhir sebelum '(' dari LINE.
Contoh: 'home: Scaffold(' → 'Scaffold'
        'return MaterialApp(' → 'MaterialApp'"
  (let ((text (my/dart-guide--line-text line)))
    (when (string-match "\\([A-Z][A-Za-z0-9_]*\\)(\\s-*$" text)
      (match-string 1 text))))

;; ── Pencari pasangan ─────────────────────────────────────────────────

(defun my/dart-guide--find-close (open-line open-indent total)
  "Cari baris penutup ')' dengan indent = OPEN-INDENT setelah OPEN-LINE.
Baris penutup valid: hanya mengandung karakter ) ; ,
Return nomor baris (0-based) atau nil."
  (let ((line (1+ open-line)) result)
    (while (and (not result) (< line total))
      (when (and (= (my/ui-guide--get-indent line) open-indent)
                 (string-match-p "^[);,]+$" (my/dart-guide--line-text line)))
        (setq result line))
      (setq line (1+ line)))
    result))

(defun my/dart-guide--child-indent (open-line close-line)
  "Indent anak langsung pertama yang tidak kosong antara OPEN-LINE dan CLOSE-LINE."
  (let ((line (1+ open-line)) result)
    (while (and (not result) (< line close-line))
      (let ((ind  (my/ui-guide--get-indent line))
            (text (my/dart-guide--line-text line)))
        (when (and (> ind 0) (not (string-empty-p text)))
          (setq result ind)))
      (setq line (1+ line)))
    result))

(defun my/dart-guide--direct-children (open-line close-line child-indent)
  "Semua baris anak langsung di CHILD-INDENT antara OPEN-LINE dan CLOSE-LINE.
v8.4: lebih robust dari named-params — menangkap SEMUA children (named params,
positional params, child:, children:) bukan hanya \\w+: pattern.
Mengabaikan: baris kosong, baris penutup (hanya mengandung );,{})."
  (let (children (line (1+ open-line)))
    (while (< line close-line)
      (let ((ind  (my/ui-guide--get-indent line))
            (text (my/dart-guide--line-text line)))
        (when (and (= ind child-indent)
                   (not (string-empty-p text))
                   ;; Bukan baris penutup/separator murni
                   (not (string-match-p "^[\\]});,]+$" text))
                   ;; Bukan baris komentar saja
                   (not (string-match-p "^//" text)))
          (push line children)))
      (setq line (1+ line)))
    (nreverse children)))

;; ── Rendering ────────────────────────────────────────────────────────

(defun my/dart-guide--add-close-label (close-line widget-name)
  "Tambah overlay ' // WIDGET-NAME' di akhir CLOSE-LINE via after-string."
  (ignore-errors
    (save-excursion
      (goto-char (point-min))
      (forward-line close-line)
      (end-of-line)
      (let ((ov (make-overlay (point) (point))))
        (overlay-put ov 'category    'my/ui-guide)
        (overlay-put ov 'after-string
                     (propertize (format " // %s" widget-name)
                                 'face '(:foreground "#00cc66" :slant italic)))
        (overlay-put ov 'priority 200)))))

(defun my/tree-guide--child-indent (open-line total parent-indent)
  "Cari indent anak langsung pertama setelah OPEN-LINE yang lebih dalam dari PARENT-INDENT.
Bekerja untuk semua tipe file berdasarkan indentasi murni."
  (let ((line (1+ open-line)) result)
    (while (and (not result) (< line total))
      (let ((ind  (my/ui-guide--get-indent line))
            (text (string-trim (or (my/ui-guide--line-content line) ""))))
        (cond
         ((string-empty-p text))                   ; baris kosong: skip
         ((> ind parent-indent) (setq result ind)) ; lebih dalam: ini child-indent
         (t (setq line total))))                    ; sama/lebih dangkal: tidak ada anak
      (setq line (1+ line)))
    result))

(defun my/tree-guide--find-close (open-line parent-indent total)
  "Cari baris akhir blok OPEN-LINE berdasarkan indentasi (universal, non-Dart).
Return baris terakhir yang masih bagian dari blok."
  (let ((line (1+ open-line)) result)
    (while (and (not result) (< line total))
      (let ((ind  (my/ui-guide--get-indent line))
            (text (string-trim (or (my/ui-guide--line-content line) ""))))
        (when (and (not (string-empty-p text)) (<= ind parent-indent))
          (setq result (1- line))))
      (setq line (1+ line)))
    (or result (1- total))))

(defun my/tree-guide--all-children (open-line close-line child-indent)
  "Semua baris anak langsung di CHILD-INDENT antara OPEN dan CLOSE.
Versi universal: hanya skip baris kosong."
  (let (children (line (1+ open-line)))
    (while (< line close-line)
      (let ((ind  (my/ui-guide--get-indent line))
            (text (string-trim (or (my/ui-guide--line-content line) ""))))
        (when (and (= ind child-indent) (not (string-empty-p text)))
          (push line children)))
      (setq line (1+ line)))
    (nreverse children)))

(defun my/tree-guide--render ()
  "Render VS Code-style tree guides (├── └── │) untuk SEMUA tipe file.
v8.6: Universal — deteksi blok murni dari indentasi, bukan syntax-specific.
      File .dart: tambah closing label // WidgetName.
      File lain : hanya tree guides tanpa label."
  (my/ui-guide-clear)
  (let ((total (count-lines (point-min) (point-max)))
        (is-dart (my/dart-guide--is-dart-buffer)))
    (when (> total 1)
      (dotimes (open-line total)
        (let* ((p-ind (my/ui-guide--get-indent open-line))
               (text  (string-trim
                       (or (my/ui-guide--line-content open-line) ""))))
          (unless (string-empty-p text)
            (let* (;; Cari child-indent: indent anak pertama yang lebih dalam
                   (c-ind (my/tree-guide--child-indent open-line total p-ind))
                   ;; Cari close-line tergantung tipe file
                   (close (when c-ind
                            (if is-dart
                                (my/dart-guide--find-close open-line p-ind total)
                              (my/tree-guide--find-close open-line p-ind total))))
                   ;; guide-col = child_indent - 3: agar ├── menggantikan
                   ;; 3 spasi sebelum isi anak → isi tetap di kolom aslinya
                   (g-col (when c-ind (- c-ind 3))))
              (when (and c-ind close g-col (>= g-col 0))
                ;; ── Dart only: closing label // WidgetName ────────────
                (when is-dart
                  (let ((wname (my/dart-guide--widget-name open-line)))
                    (when wname
                      (my/dart-guide--add-close-label close wname))))
                ;; ── Tree guides ├──/└──/│ untuk semua tipe file ───────
                (let* ((children (if is-dart
                                     (my/dart-guide--direct-children
                                      open-line close c-ind)
                                   (my/tree-guide--all-children
                                    open-line close c-ind)))
                       (n (length children)))
                  (dotimes (i n)
                    (let* ((cl      (nth i children))
                           (is-last (= i (1- n)))
                           (next-cl (unless is-last (nth (1+ i) children))))
                      ;; ├── atau └── di baris anak
                      (my/ui-guide--place-ov
                       cl g-col
                       (if is-last "└──" "├──")
                       (if is-last 'my/ui-guide-active-face 'my/ui-guide-face))
                      ;; │ di baris antara non-last anak & sibling berikutnya
                      (unless is-last
                        (when next-cl
                          (let ((from (1+ cl)))
                            (while (< from next-cl)
                              (my/ui-guide--place-ov
                               from g-col "│" 'my/ui-guide-face)
                              (setq from (1+ from)))))))))))))))))


;; [OPT] Throttle dengan idle-timer — jauh lebih efisien daripada post-command-hook
(defvar my/ui-guide--timer nil
  "Idle timer untuk throttle update UI Guides.")

(defvar my/ui-guide--update-delay
  (if my/is-termux 0.5 0.25)
  "Delay (detik) sebelum UI Guides di-update setelah idle.")

(defun my/dart-guide--is-dart-buffer ()
  "Non-nil jika buffer ini adalah Dart file."
  (or (eq major-mode 'dart-mode)
      (and buffer-file-name
           (string-match-p "\\.dart\\'" buffer-file-name))))

(defun my/ui-guide-update ()
  "Update UI Guides (dipanggil via idle-timer).
v8.6: my/tree-guide--render dipakai untuk SEMUA tipe file.
      Dart → tree guides + closing labels.
      Semua lain → tree guides saja (├── └── │ dari indentasi)."
  (when (and my/ui-guide-mode
             (not (minibufferp))
             (not (string-prefix-p "*" (buffer-name)))
             (> (buffer-size) 0))
    (my/tree-guide--render)))


(defun my/dart-guide-diagnose ()
  "Tampilkan info diagnostik Flutter Widget Guides di buffer saat ini.
Jalankan dari buffer .dart yang ingin diperiksa."
  (interactive)
  (let* ((is-dart  (my/dart-guide--is-dart-buffer))
         (total    (count-lines (point-min) (point-max)))
         (openers  '())
         (buf      (get-buffer-create "*Dart Guide Diagnose*")))
    ;; Kumpulkan widget openers
    (dotimes (line total)
      (when (my/dart-guide--is-opener line)
        (let* ((p-ind (my/ui-guide--get-indent line))
               (close (my/dart-guide--find-close line p-ind total))
               (c-ind (when close (my/dart-guide--child-indent line close)))
               (g-col (when c-ind (- c-ind 3)))
               (kids  (when (and close c-ind g-col (>= g-col 0))
                        (my/dart-guide--direct-children line close c-ind))))
          (push (list (1+ line)
                      (my/dart-guide--widget-name line)
                      p-ind c-ind g-col
                      (length (or kids '())))
                openers))))
    (with-current-buffer buf
      (read-only-mode -1)
      (erase-buffer)
      (insert "╔══ DART GUIDE DIAGNOSE ══════════════════════╗\n")
      (insert (format "  File      : %s\n" (or buffer-file-name "(tidak ada)")))
      (insert (format "  major-mode: %s\n" major-mode))
      (insert (format "  dart-buf-p: %s\n" is-dart))
      (insert (format "  ui-guide  : %s\n" (if (bound-and-true-p my/ui-guide-mode)
                                               "AKTIF" "tidak aktif")))
      (insert (format "  total baris: %d\n" total))
      (insert "╠══ Widget Openers ═══════════════════════════╣\n")
      (if openers
          (dolist (o (nreverse openers))
            (insert (format "  Baris %-4d │ %-20s│ p=%d c=%s g=%s children=%d\n"
                            (nth 0 o) (or (nth 1 o) "?")
                            (nth 2 o)
                            (if (nth 3 o) (number-to-string (nth 3 o)) "nil")
                            (if (nth 4 o) (number-to-string (nth 4 o)) "nil")
                            (nth 5 o))))
        (insert "  (tidak ada widget opener ditemukan)\n"))
      (insert "╚═════════════════════════════════════════════╝\n")
      (read-only-mode 1))
    (pop-to-buffer buf)))

(defun my/ui-guide--schedule-update ()
  "Jadwalkan update UI Guides via idle timer (throttled)."
  (when my/ui-guide--timer
    (cancel-timer my/ui-guide--timer))
  (setq my/ui-guide--timer
        (run-with-idle-timer my/ui-guide--update-delay nil
                             #'my/ui-guide-update)))

;; ROBUST: Mode enable/disable
(defun my/ui-guide-mode-enable ()
  "Aktifkan UI Guides mode."
  (my/ui-guide-update)
  ;; [OPT] Pakai post-command untuk menjadwalkan idle-timer, bukan langsung update
  (add-hook 'post-command-hook #'my/ui-guide--schedule-update nil t))

(defun my/ui-guide-mode-disable ()
  "Matikan UI Guides mode."
  (when my/ui-guide--timer
    (cancel-timer my/ui-guide--timer)
    (setq my/ui-guide--timer nil))
  (my/ui-guide-clear)
  (remove-hook 'post-command-hook #'my/ui-guide--schedule-update t))

(define-minor-mode my/ui-guide-mode
  "Mode untuk UI Guides di semua file."
  :global nil
  :init-value nil
  :lighter " UG"
  (if my/ui-guide-mode
      (my/ui-guide-mode-enable)
    (my/ui-guide-mode-disable)))

;; ROBUST: Auto-enable dengan delay
(defun my/ui-guide-auto-enable ()
  "Auto-enable UI Guides dengan guard."
  (when (and (not (minibufferp))
             (not (string-prefix-p "*" (buffer-name)))
             (not (derived-mode-p 'special-mode)))
    (my/ui-guide-mode 1)))

;; Delay activation untuk hindari startup error
(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-timer 1 nil
                            (lambda ()
                              ;; after-change-major-mode-hook: untuk file yang mode-nya berubah
                              (add-hook 'after-change-major-mode-hook
                                        #'my/ui-guide-auto-enable)
                              ;; find-file-hook: untuk file yang langsung buka di fundamental-mode
                              ;; (mis. .dart tanpa dart-mode, .txt, dsb.) — mode TIDAK berubah
                              ;; sehingga after-change-major-mode-hook tidak terpicu
                              (add-hook 'find-file-hook
                                        #'my/ui-guide-auto-enable)
                              ;; Aktifkan di buffer yang sudah terbuka
                              (dolist (buf (buffer-list))
                                (with-current-buffer buf
                                  (my/ui-guide-auto-enable)))))))

(defun my/ui-guide-toggle ()
  "Toggle UI Guides."
  (interactive)
  (if my/ui-guide-mode
      (progn (my/ui-guide-mode -1) (message "[NZR] UI Guides: OFF"))
    (my/ui-guide-mode 1) (message "[NZR] UI Guides: ON")))

(defun my/ui-guide-refresh ()
  "Refresh UI Guides."
  (interactive)
  (my/ui-guide-clear)
  (my/ui-guide-update)
  (message "[NZR] UI Guides refreshed"))

(global-set-key (kbd "C-c g") #'my/ui-guide-toggle)
(global-set-key (kbd "C-c G") #'my/ui-guide-refresh)

;; ════════════════════════════════════════════════════════════════════════
;; §10-C  DIAGNOSTIC (Diperluas — termasuk treemacs, rainbow, UI Guide)
;; ════════════════════════════════════════════════════════════════════════

(defun my/flutter-diagnostic ()
  "Diagnostic report lengkap: environment, package, path, dan mode aktif."
  (interactive)
  (let ((buf (get-buffer-create "*Flutter Diagnostic v8.7*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "╔══════════════════════════════════════════════════════╗\n")
      (insert "║     FLUTTER/LSP DIAGNOSTIC REPORT v8.7               ║\n")
      (insert "╚══════════════════════════════════════════════════════╝\n\n")

      ;; Environment
      (insert "━━━ Environment ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert (format "  Emacs version : %s\n" emacs-version))
      (insert (format "  Emacs 29+     : %s\n" (if my/is-emacs29+ "YES" "NO")))
      (insert (format "  Treesit       : %s\n" (if my/ui-guide-use-treesit "YES" "NO")))
      (insert (format "  Termux        : %s\n" (if my/is-termux "YES" "NO")))
      (insert (format "  GUI           : %s\n" (if my/is-gui "YES" "NO")))
      (insert (format "  Desktop       : %s\n" (if my/is-desktop "YES" "NO")))
      (insert (format "  System type   : %s\n\n" system-type))

      ;; Flutter/Dart SDK Paths
      (insert "━━━ SDK Paths ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert (format "  flutter (PATH) : %s\n"
                      (or (executable-find "flutter") "NOT FOUND")))
      (insert (format "  dart (PATH)    : %s\n"
                      (or (executable-find "dart") "NOT FOUND")))
      (insert (format "  FLUTTER_ROOT   : %s\n"
                      (or (getenv "FLUTTER_ROOT") "not set")))
      (insert (format "  DART_SDK       : %s\n\n"
                      (or (getenv "DART_SDK") "not set")))

      ;; Packages
      (insert "━━━ Packages ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (dolist (pkg '(dart-mode lsp-mode lsp-dart lsp-ui lsp-treemacs
                     flutter treemacs rainbow-delimiters
                     company flycheck yasnippet gcmh which-key))
        (insert (format "  %-22s: %s\n"
                        (symbol-name pkg)
                        (if (featurep pkg) "✓ loaded" "✗ not loaded"))))
      (insert "\n")

      ;; Current buffer mode status
      (insert "━━━ Buffer saat ini ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert (format "  Major mode     : %s\n" major-mode))
      (insert (format "  UI Guide mode  : %s\n"
                      (if (bound-and-true-p my/ui-guide-mode) "ON" "OFF")))
      (insert (format "  Treesit indent : %s\n"
                      (if my/ui-guide-use-treesit "ACTIVE" "inactive")))
      (insert (format "  LSP mode       : %s\n"
                      (if (bound-and-true-p lsp-mode) "ON" "OFF")))
      (insert (format "  Company mode   : %s\n"
                      (if (bound-and-true-p company-mode) "ON" "OFF")))
      (insert (format "  Flycheck mode  : %s\n"
                      (if (bound-and-true-p flycheck-mode) "ON" "OFF")))
      (insert (format "  YASnippet mode : %s\n\n"
                      (if (bound-and-true-p yas-minor-mode) "ON" "OFF")))

      ;; System resources
      (insert "━━━ System Resources ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert (format "  RAM            : %s\n" my/cache-ram))
      (insert (format "  Disk           : %s\n" my/cache-disk))
      (insert (format "  CPU            : %s\n\n" my/cache-cpu))

      (insert "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
      (insert "Tekan 'q' untuk menutup buffer ini.\n")
      (local-set-key (kbd "q") #'kill-this-buffer))
    (pop-to-buffer buf)))


;; ════════════════════════════════════════════════════════════════════════
;; §11 POWERLINE CUSTOM — Header + Mode-line dengan async cache
;; ════════════════════════════════════════════════════════════════════════

(defvar my/pl-sep-left  "\ue0b0")
(defvar my/pl-sep-right "\ue0b2")

(defun my/pl-seg (text fg bg &optional next-bg)
  "Segment powerline: TEXT dengan warna FG/BG, separator ke NEXT-BG."
  (when (and text (stringp text) (not (string-empty-p (string-trim text))))
    (concat
     (propertize (concat " " (string-trim text) " ")
                 'face `(:background ,bg :foreground ,fg :weight bold))
     (when next-bg
       (propertize my/pl-sep-left
                   'face `(:foreground ,bg :background ,next-bg))))))

;; ── Cache variabel ────────────────────────────────────────────────────
(defvar my/cache-disk   "DISK: ..." "Cache penggunaan disk.")
(defvar my/cache-ram    "RAM: ..."  "Cache penggunaan RAM.")
(defvar my/cache-cpu    "CPU: ..."  "Cache jumlah core CPU.")
(defvar my/cache-termux ""          "Cache versi Termux.")

;; ── Zero-subprocess RAM reader ────────────────────────────────────────
;; [REF] (condition-case nil ... (error nil)) → (ignore-errors ...)
(defun my/read-ram-proc ()
  "Baca RAM dari /proc/meminfo — zero subprocess, pure memory I/O."
  (or (ignore-errors
        (with-temp-buffer
          (insert-file-contents "/proc/meminfo")
          (goto-char (point-min))
          (when (re-search-forward "MemTotal:\\s-+\\([0-9]+\\)\\s-+kB" nil t)
            (let ((total-kb (string-to-number (match-string 1))))
              (goto-char (point-min))
              (if (re-search-forward "MemAvailable:\\s-+\\([0-9]+\\)\\s-+kB" nil t)
                  (let* ((avail-kb (string-to-number (match-string 1)))
                         (used-kb  (- total-kb avail-kb))
                         (used-mb  (/ used-kb 1024))
                         (total-mb (/ total-kb 1024))
                         (pct      (if (> total-kb 0)
                                       (/ (* used-kb 100) total-kb)
                                     0)))
                    (format "RAM %dM/%dM (%d%%)" used-mb total-mb pct))
                (format "RAM %dM total" (/ total-kb 1024)))))))
      "RAM N/A"))

;; [OPT] Disk cache: dijaga dengan with-demoted-errors, tidak block UI
(defun my/update-disk-cache ()
  "Update disk cache. Hanya desktop, dengan penjagaan error penuh."
  (when (and my/is-desktop
             (not my/is-termux)
             (executable-find "df"))
    (with-demoted-errors "[NZR disk-cache] %s"
      (with-temp-buffer
        (when (zerop (call-process "df" nil t nil "-h" "/"))
          (goto-char (point-min))
          (forward-line 1)
          (when (re-search-forward
                 "\\S-+\\s-+\\S-+\\s-+\\(\\S-+\\)\\s-+\\(\\S-+\\)\\s-+\\([0-9]+%\\)"
                 nil t)
            (setq my/cache-disk
                  (format "DISK %s/%s (%s)"
                          (match-string 1)
                          (match-string 2)
                          (match-string 3)))))))))

;; ── Main cache updater ────────────────────────────────────────────────
(defun my/update-sys-cache ()
  "Update cache info sistem. Non-blocking dan battery-friendly."
  (setq my/cache-cpu
        (if (fboundp 'num-processors)
            (format "CPU %d core" (num-processors))
          "CPU N/A"))
  (setq my/cache-ram (my/read-ram-proc))
  (my/update-disk-cache)
  (setq my/cache-termux
        (if my/is-termux
            (format "Termux %s" (or (getenv "TERMUX_VERSION") "?"))
          "")))

(my/update-sys-cache)
(run-with-idle-timer 15 t #'my/update-sys-cache)

;; ── HEADER LINE (atas) ───────────────────────────────────────────────
(setq-default header-line-format
  '(:eval
    (let* ((path  (or (buffer-file-name) (concat "[" (buffer-name) "]")))
           (fname (if (buffer-file-name)
                      (abbreviate-file-name path)
                    path))
           (fsize (if (buffer-file-name)
                      (format "%d B" (buffer-size))
                    "N/A"))
           (mod   (if (buffer-modified-p) "● MODIFIED" "✓ SAVED"))
           (lines (format "L:%d" (count-lines (point-min) (point-max)))))
      (concat " "
              (my/pl-seg fname "#e0e0e0" "#1a1a2e" "#16213e")
              (my/pl-seg fsize "#e0e0e0" "#16213e" "#0f3460")
              (my/pl-seg mod   "#ffffff" "#0f3460" "#533483")
              (my/pl-seg lines "#e0e0e0" "#533483" nil)))))

(set-face-attribute 'header-line nil
  :background "#000000" :foreground "#888888"
  :box nil :underline nil :overline nil)

;; ── MODE LINE (bawah) ────────────────────────────────────────────────
(setq-default mode-line-format
  '(:eval
    (concat " "
            (my/pl-seg (symbol-name major-mode) "#ffffff" "#e94560" "#0f3460")
            (my/pl-seg my/cache-disk            "#ffffff" "#0f3460" "#533483")
            (my/pl-seg my/cache-ram             "#ffffff" "#533483" "#1a1a2e")
            (my/pl-seg my/cache-cpu             "#e0e0e0" "#1a1a2e" "#16213e")
            (when (and my/is-termux
                       (not (string-empty-p my/cache-termux)))
              (my/pl-seg my/cache-termux "#e0e0e0" "#0f3460" nil)))))

(set-face-attribute 'mode-line nil
  :background "#000000" :foreground "#888888" :box nil)
(set-face-attribute 'mode-line-inactive nil
  :background "#111111" :foreground "#555555" :box nil)

;; ════════════════════════════════════════════════════════════════════════
;; §12 SHORTCUTS
;; ════════════════════════════════════════════════════════════════════════

(xterm-mouse-mode t)
(global-set-key [mouse-4] 'scroll-down-line)
(global-set-key [mouse-5] 'scroll-up-line)

(global-set-key (kbd "C-s")     'isearch-forward)
(global-set-key (kbd "C-x C-s") 'save-buffer)
(global-set-key (kbd "C-f")     'find-file)
(global-set-key (kbd "<f2>")    'find-file)
(global-set-key (kbd "<f3>")    'save-buffer)
(global-set-key (kbd "<f4>")    'kill-this-buffer)
(global-set-key (kbd "<f5>")    'revert-buffer)
(global-set-key (kbd "<f7>")    #'my/flutter-diagnostic)
(global-set-key (kbd "<f12>")
  (lambda () (interactive) (find-file "~/.emacs")))

(global-set-key (kbd "<f8>")   #'my/flutter-outline-toggle)
(global-set-key (kbd "<f9>")   #'my/flutter-hot-reload)
(global-set-key (kbd "S-<f9>") #'my/flutter-hot-restart)

(global-set-key (kbd "M-<left>")  'windmove-left)
(global-set-key (kbd "M-<right>") 'windmove-right)
(global-set-key (kbd "M-<up>")    'windmove-up)
(global-set-key (kbd "M-<down>")  'windmove-down)

(global-set-key (kbd "C-x |")
  (lambda () (interactive) (split-window-right) (windmove-right)))
(global-set-key (kbd "C-x -")
  (lambda () (interactive) (split-window-below) (windmove-down)))

;; ════════════════════════════════════════════════════════════════════════
;; §13 BENCHMARK — tampilkan ringkasan startup di echo area
;; ════════════════════════════════════════════════════════════════════════

(add-hook 'emacs-startup-hook
  (lambda ()
    (message
     (concat "[NZR] v8.7 | %.2fs | GC×%d | %s | "
             "Byte-compile: ON | GCMH: ON (%dMB) | "
             "UI-Guide: throttled idle %.2fs | "
             "Palette: 8 depth | Bracket: rainbow-delimiters | "
             "Flutter: %s | Emacs29+: %s")
     (float-time (time-subtract after-init-time before-init-time))
     gcs-done
     (cond (my/is-termux  "Termux Android")
           (my/is-desktop "Desktop")
           (t             "Terminal"))
     (/ (if my/is-termux (* 32 1024 1024) (* 128 1024 1024))
        (* 1024 1024))
     my/ui-guide--update-delay
     (if (package-installed-p 'lsp-dart) "lsp-dart ✓" "lsp-dart ✗")
     (if my/is-emacs29+ "✓" "✗"))))

;; ════════════════════════════════════════════════════════════════════════
;; END OF ~/.emacs  v8.7  (Byte-Compile Fix)
;; ════════════════════════════════════════════════════════════════════════
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(company-quickhelp flutter flycheck gcmh highlight-indent-guides
                       indent-bars lsp-dart lsp-ui org-bullets
                       org-modern rainbow-delimiters undo-fu
                       yasnippet-snippets)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
