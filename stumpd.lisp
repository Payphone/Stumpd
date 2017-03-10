;;;; stumpd.lisp

(in-package #:stumpd)

;; Utilities

(defun escape-spaces (string)
  "Inserts a backslash before every space in a string."
  (coerce (loop for char across string
             if (char= char #\Space) collect #\\
             collect char) 'string))

(defun 2cons (elt1 elt2 lst)
  "Conses two elements to a list."
  (cons elt2 (cons elt1 lst)))

(defun quote-string (string)
  "Encloses a string in double quotes."
  (concatenate 'string "\"" string "\""))

;; Connection Settings

(defvar *socket* (initialize-connection "localhost" 6600))

(defmacro auto-reconnect (socket &body body)
  "Reconnects socket when it closes. MPD automatically closes clients after a
  period of time."
  `(handler-case
       (progn ,@body)
     (error ()
       (setf ,socket (initialize-connection "localhost" 6600))
       ,@body)))

(defmacro define-mpd-command (name (&rest args) (&rest interactive-args)
                              &body body)
  "Defines a mpd command using the StumpWM defcommand wrapped with an
  auto-reconnect."
  `(defcommand ,name (,@args) (,@interactive-args)
     (auto-reconnect *socket*
       ,@body)))

;; Playback

(define-mpd-command set-volume (volume) ((:string "Volume (1-100): "))
  (playback-set-volume *socket* volume))

(define-mpd-command pause/resume () ()
  (let ((state (state (query-status *socket*))))
    (if (string= state "pause")
        (progn (playback-pause *socket* nil) (current-song))
        (progn (playback-pause *socket* t) (message "Paused.")))))

(define-mpd-command play (&optional song-position) ((:string "Position: "))
  (playback-play *socket* song-position))

(define-mpd-command previous-song () ()
  (playback-previous *socket*)
  (current-song))

(define-mpd-command next-song () ()
  (playback-next *socket*)
  (current-song))

(define-mpd-command stop () ()
  (playback-stop *socket*)
  (message "Stopped."))

;; Playlist

(define-mpd-command add-song (song) ((:string "File: "))
  (playlist-add-song *socket* song))

(define-mpd-command clear-songs () ()
  (playlist-clear-songs *socket*))

(define-mpd-command delete-song (song) ((:string "File: "))
  (playlist-delete-song *socket* song))

;; Queries

(define-mpd-command current-song () ()
  (let ((song (query-song *socket*)))
    (message "~A~%~A~%~A" (or (title song) "Unknown") (or (artist song) "")
             (or (album song) ""))
    (or (title song) "Unknown")))

;; Browsing
(defclass file ()
  ((last-modified :initarg :last-modified :accessor last-modified)
   (size :initarg :size :accessor size)
   (name :initarg :name :accessor name)))

(defclass file-directory ()
  ((last-modified :initarg :last-modified :accessor last-modified)
   (size :initarg :size :accessor size)
   (name :initarg :name :accessor name)))

(defun group-files (lst &optional build acc)
  "Creates a list of parameter lists containing a file/directory."
  (if lst
      (let ((key (car lst))
            (value (cadr lst)))
        (if (or (eq key 'file) (eq key 'directory))
            (group-files (cddr lst) nil
                         (append (list (reverse (2cons key value build))) acc))
            (group-files (cddr lst) (2cons key value build) acc)))
      (reverse acc)))

(defun browse-directory (directory)
  (let ((files (group-files (database-list-files *socket*
                              (quote-string (escape-spaces directory))))))
    (loop for file in files
       collect (make-instance (if (getf file 'file) 'file 'file-directory)
                              :last-modified (getf file 'last-modified)
                              :size (getf file 'size)
                              :name (or (getf file 'file)
                                        (getf file 'directory))))))

#|
(select-from-menu (current-screen) options title
                  (or initial-selection 0)
                  keymap)
|#
;; Keybindings

(defvar *mpd-playback-map*
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c") "reconnect")
    (define-key map (kbd "v") "set-volume")
    (define-key map (kbd "p") "pause/resume")
    (define-key map (kbd "P") "play")
    (define-key map (kbd "<") "previous-song")
    (define-key map (kbd ">") "next-song")
    (define-key map (kbd "s") "stop")
    (define-key map (kbd "a") "add-song")
    (define-key map (kbd "c") "clear-songs")
    (define-key map (kbd "d") "delete-song")
    (define-key map (kbd "S") "current-song")
    map))