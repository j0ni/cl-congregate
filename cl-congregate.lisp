;;;; cl-congregate.lisp
(in-package #:cl-congregate)

(define-handler (root) ()
  (page (:title "congregate.ca")
    (:ul
     (loop for g in (list-groups)
	do (htm
	    (:li (:a :href (format nil "/group?group=~a" (getf g :id))
		     (str (getf g :name)))))))))

;; TODO - create new group

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Groups
(define-handler (group) ((group :group))
  (page (:title (getf group :name))
    (:h2 (fmt "Recurring ~a on ~a at ~a to ~a"
	      (getf group :recurring) (getf group :on)
	      (getf group :at) (getf group :to)))
    (:iframe :class "map" :src (group-map-url group))
    (when (organizer-of? (lookup :user session) group)
      (htm (:a :href (format nil "/group/create-event-form?group=~a" (getf group :id)) "Create Event")))
    (:div
     :class "column"
     (:h3 "Resources")
     (:ul
      (loop for (k v) on (getf group :links) by #'cddr
	 do (htm (:li (:a :href v (str k)))))))
    (:div
     :class "column"
     (:h3 "Upcoming Events")
     (:ul
      (loop for e in (group-events (getf group :id))
	 do (htm (:li (:a :href (format nil "/event?event=~a" (getf e :id))
			  (str (getf e :name))))))))
    (:div
     :class "column"
     (:h3 "Organizers")
     (:ul
      (loop for o in (getf group :organizers)
	 do (htm (:li (user-link o))))))
    (:hr :class "clear")
    (:p (str (getf group :description)))))
;; TODO - group should allow editing in-line for administrators

(define-handler (group/create-event-form) ((group :group))
  (page (:title (format nil "New Event for ~a" (getf group :name)))
    (:form
     (:input :type "text" :name "name")
     (:input :type "text" :name "location")
     (:input :type "text" :name "datetime")
     (:input :type "submit" :value "Create"))))

(define-handler (group/create-event) ((group :group) (name :string) (location :string) (date :string) (at :integer) (to :integer))
  (cond ((organizer-of? (lookup :user session) group)
	 (let ((event (create-event! group :name name :location location :date date)))
	   (redirect! (format nil "/event?event=~a" (getf event :id)))))
	(t
	 (setf (lookup :destination session)
	       (format
		nil "/group/create-event?group=~a&name=~a&location=~a&datetime=~a"
		(getf group :id) name location datetime)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Events
(define-handler (event) ((event :event))
  (page (:title (getf event :name))
    (:iframe :class "map" :src (event-map-url event))
    (:h2 (fmt "On ~a at ~a to ~a"
	      (local-time:format-timestring
	       nil (getf event :date)
	       :format '(:long-weekday " the " :ordinal-day " of " :short-month ", " :year))
	      (getf event :at) (getf event :to)))
    (:a :href (format nil "/event/interested?event=~a" (getf event :id))
	"I'll Be There!")
    (:h2 "Attending")
    (:ul (loop for u in (getf event :interested)
	    do (htm (:li (user-link u)))))))
;; TODO - events should allow editing in-line for group administrators

;; TODO - delete event

(define-handler (event/take-attendance) ((event :event) (attendees :list-of-string))
  (cond ((organizer-of? (lookup :user session) event)
	 (take-attendance attendees event)
	 (redirect! (format nil "/event?event=~a" (getf event :id))))
	(t
	 (setf (lookup :destination session)
	       (format nil "/event/interested?event=~a" (getf event :id)))
	 (redirect! "https://github.com/login/oauth/authorize?client_id=50798a26a6cdfa15a5b8"))))

(define-handler (event/interested) ((event :event))
  (cond ((lookup :user session)
	 (register-interest (lookup :user session) event)
	 (redirect! (format nil "/event?event=~a" (getf event :id))))
	(t
	 (setf (lookup :destination session)
	       (format nil "/event/interested?event=~a" (getf event :id)))
	 (redirect! "https://github.com/login/oauth/authorize?client_id=50798a26a6cdfa15a5b8"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Authentication
(define-handler (auth/github/callback :content-type "text/plain") ((code :string))
  (let* ((raw (drakma:http-request
	       "https://github.com/login/oauth/access_token"
	       :method :post
	       :parameters (list
			    (cons "client_id" +github-api-id+)
			    (cons "client_secret" +github-api-secret+)
			    (cons "code" code))))
	 (params (house::parse-params (map 'string #'code-char raw))))
    (aif (cdr (assoc :access_token params))
	 (let* ((raw (drakma:http-request
		      "https://api.github.com/user"
		      :parameters (list (cons "access_token" it))))
		(u (yason:parse (map 'string #'code-char raw) :object-key-fn #'house::->keyword)))
	   (setf (lookup :user session)
		 (make-instance
		  'user
		  :source :github :access-token it
		  :name (gethash :login u) :url (gethash :html_url u)))
	   (let ((dest (lookup :destination session)))
	     (setf (lookup :destination session) nil)
	     (redirect! (or dest "/"))))
	 "AUTHENTICATION ERROR")))
