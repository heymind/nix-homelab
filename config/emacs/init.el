;;; init.el --- Emacs 配置入口 -*- lexical-binding: t -*-


(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(set-language-environment "UTF-8")

(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)

(set-file-name-coding-system 'utf-8)

(setq locale-coding-system 'utf-8)
;; (setq treesit-font-lock-level 4)

(setenv "LANG" "en_US.UTF-8")
(setenv "LC_ALL" "en_US.UTF-8")
(setenv "LC_CTYPE" "en_US.UTF-8")

(use-package
 no-littering
 :config (no-littering-theme-backups) (require 'recentf)
 (add-to-list
  'recentf-exclude
  (recentf-expand-file-name no-littering-var-directory))
 (add-to-list
  'recentf-exclude
  (recentf-expand-file-name no-littering-etc-directory)))

(require 'org)

(defvar my/config-org
  (expand-file-name "config.org" user-emacs-directory))



(when (file-exists-p my/config-org)
  (org-babel-load-file my/config-org))

(provide 'init)
