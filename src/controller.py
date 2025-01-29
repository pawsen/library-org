from flask import Flask, render_template, redirect, url_for, flash, request, session
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.sql.expression import or_, asc, desc
from flask_wtf import FlaskForm
from wtforms import SelectField
import requests, json, configparser, os, re, sys, pprint
from pathlib import Path

# Configuration setup
p = Path(__file__).absolute()
CONFIG_FILE = "library.cfg"
PROJECT_ROOT = p.parent
CONFIG_PATH = next((fpath / CONFIG_FILE for fpath in [p.parents[1], PROJECT_ROOT] if (fpath / CONFIG_FILE).is_file()), None)
if not CONFIG_PATH:
    sys.exit(f"{CONFIG_FILE} not found in src or parent dir. Create it from 'LIBRARY.cfg_EXAMPLE'.")

CONFIG = configparser.ConfigParser()
CONFIG.read(CONFIG_PATH)
APP_SECRET_KEY = CONFIG.get("secrets", "APP_SECRET_KEY")
USER = {"username": CONFIG.get("secrets", "USERNAME"), "password": CONFIG.get("secrets", "PASSWORD")}

# Database setup
db_name = "books.sqlite"
sqlite_db = f"sqlite:////{os.path.join(PROJECT_ROOT, 'database', db_name)}"
app = Flask(__name__)
app.secret_key = APP_SECRET_KEY
app.debug = True
app.config["SQLALCHEMY_DATABASE_URI"] = sqlite_db
db = SQLAlchemy(app)
migrate = Migrate(app, db)
PAGINATE_BY_HOWMANY = 50


class Location(db.Model):
    """Locations have a shortname and a pkey ID.

    Books are linked to location by ForeignKey using the ID (pkey).
    """

    id = db.Column(db.Integer, primary_key=True)
    label_name = db.Column(db.String(20), unique=True)
    full_name = db.Column(db.String(100), unique=False)
    # books = db.relationship("Book", backref="person", lazy="dynamic")

    def __init__(self, label_name, full_name):
        self.label_name = label_name
        self.full_name = full_name

    def __repr__(self):
        return "<Location Label: >".format(self.label_name)


class TransactionLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=db.func.current_timestamp())  # Auto-timestamp
    action = db.Column(db.String(50), nullable=False)  # "ADD", "EDIT", "DELETE"
    book_id = db.Column(db.Integer, db.ForeignKey("book.id"), nullable=True)  # Reference the book
    book_title = db.Column(db.String(200))  # Store the title at the time of change
    details = db.Column(db.Text)  # Store what changed


class Book(db.Model):
    """Build a model based on the available fields in the openlibrary.org API.

    Notes:
        authors - will be stored as a long string, openlibrary delivers it as a list of objects.

    Additional info:
        curl 'https://openlibrary.org/api/books?bibkeys=ISBN:9780980200447&jscmd=data&format=json'
        using jscmd=data yields less info but is more stable
        using jscmd=details will give us book cover thumbnail, preview url, table of contents, and more

    Enhancements:
        use jscmd=details to get cover thumbnail... this could be a key piece of the template
    """

    id = db.Column(db.Integer, primary_key=True)
    isbn = db.Column(db.String(20), unique=False)
    olid = db.Column(db.String(20), unique=False)
    lccn = db.Column(db.String(20), unique=False)
    title = db.Column(db.String(200), unique=False)
    authors = db.Column(db.String(200), unique=False)
    publish_date = db.Column(db.String(30), unique=False)
    number_of_pages = db.Column(db.String(10), unique=False)
    subjects = db.Column(db.String(5000), unique=False)
    openlibrary_medcover_url = db.Column(db.String(500), unique=False)
    openlibrary_preview_url = db.Column(db.String(500), unique=False)
    dewey_decimal_class = db.Column(db.String(50), unique=False)
    location = db.Column(
        db.Integer, db.ForeignKey("location.id"), default=None, nullable=True
    )

    def __init__(self, **kwargs):
        super(Book, self).__init__(**kwargs)

    def __repr__(self):
        return "<Title: >".format(self.title)


class LocationForm(FlaskForm):
    # attach form.location.choices = location_options after instantiation!!
    # http://wtforms.readthedocs.io/en/latest/fields.html#wtforms.fields.SelectField
    location = SelectField(coerce=int)


# Helper functions
def fetch_book_details(isbn):
    # fetch book details using an ISBN
    google_books_url = f'https://www.googleapis.com/books/v1/volumes?q=isbn:{isbn}'
    open_library_url = f'https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data'

    # Fetch data from Open Library
    open_library_response = requests.get(open_library_url)
    open_library_data = open_library_response.json() if open_library_response.status_code == 200 else {}
    # pprint.pprint((open_library_data))

    book_details = {}
    # Open Library data
    if f'ISBN:{isbn}' in open_library_data:
        open_library_info = open_library_data[f'ISBN:{isbn}']

        # Extract title and subtitle from Open Library (if available)
        open_library_title = open_library_info.get('title', '')
        open_library_subtitle = open_library_info.get('subtitle', '')
        # Combine title and subtitle (if subtitle exists)
        if open_library_subtitle:
            book_details['title'] = f"{open_library_title} - {open_library_subtitle}"
        else:
            book_details['title'] = open_library_title

        book_details['authors'] = [author['name'] for author in open_library_info.get('authors', [])]
        book_details['publishedDate'] = open_library_info.get('publish_date', '')
        book_details['description'] = open_library_info.get('description', '')
        # Extract and store only the names of the subjects
        book_details['subjects'] = [subject['name'] for subject in open_library_info.get('subjects', [])]
        book_details['number_of_pages'] = open_library_info.get('number_of_pages', '')
        book_details['preview_link'] = f"https://openlibrary.org{open_library_info.get('key', '')}"  # Link to borrow or more info
        book_details['thumbnail'] = open_library_info.get('cover', {}).get('medium', '')

    # If no Open Library data, try Google Books
    if not book_details.get('title'):
        google_books_response = requests.get(google_books_url)
        google_books_data = google_books_response.json() if google_books_response.status_code == 200 else {}
        # pprint.pprint((google_books_data))

        if 'items' in google_books_data:
            google_book = google_books_data['items'][0]
            google_info = google_book.get('volumeInfo', {})

            google_title = google_info.get('title', '')
            google_subtitle = google_info.get('subtitle', '')
            # Combine title and subtitle (if subtitle exists)
            if google_subtitle:
                book_details['title'] = f"{google_title} - {google_subtitle}"
            else:
                book_details['title'] = google_title

            book_details['authors'] = google_info.get('authors', [])
            book_details['publishedDate'] = google_info.get('publishedDate', '')
            book_details['description'] = google_info.get('description', '')
            book_details['thumbnail'] = google_info.get('imageLinks', {}).get('thumbnail', '')
            book_details['subjetcs'] = google_info.get('categories', [])
            book_details['number_of_pages'] = google_info.get('pageCount', '')
            book_details['preview_link'] = google_info.get('previewLink', '')

    # Return the combined details
    return book_details

def check_isbn(isbn:str|None) -> bool:
    """Check we have a ISBN

    https://stackoverflow.com/a/4047709
    https://rosettacode.org/wiki/ISBN13_check_digit#Python
    """

    if isbn is None:
        return False

    isbn = isbn.replace("-", "").replace(" ", "").upper();
    if len(isbn) == 10:
        match = re.search(r'^(\d{9})(\d|X)$', isbn)
        if not match:
            return False

        digits = match.group(1)
        check_digit = 10 if match.group(2) == 'X' else int(match.group(2))

        result = sum((i + 1) * int(digit) for i, digit in enumerate(digits))
        return (result % 11) == check_digit
    else:
        result = (sum(int(ch) for ch in isbn[::2]) + sum(int(ch) * 3 for ch in isbn[1::2]))
        return result % 10 == 0

def login_required():
    """Redirects to login page if user is not logged in."""
    if not session.get("logged_in"):
        flash("You must be logged in to perform this action.", "danger")
        return redirect(url_for("login"))
    return None


# routes
@app.route("/index")
@app.route("/")
def home():
    return redirect(url_for("index", page=1))

@app.route("/add_book", methods=["GET", "POST"])
def add_book():
    """Add a new book to the system by entering ISBN or manually filling fields."""
    auth_redirect = login_required()
    if auth_redirect:
        return auth_redirect

    # Fetch locations from the database (or use predefined list if necessary)
    locations = Location.query.order_by("label_name").all()
    location_choices = [(l.id, f"{l.label_name}, {l.full_name}") for l in locations]  # Populate choices dynamically
    location_form = LocationForm()

    # Pre-fill location choices
    location_form.location.choices = location_choices + [(-1, u"-- Add the correct location --")]

    if request.method == "POST":
        if "search_isbn" in request.form:  # Handle ISBN search
            isbn = request.form.get("isbn")
            if not check_isbn(isbn):
                return "Invalid ISBN. Please enter a valid 10 or 13-digit ISBN."

            # Fetch book details from both Google Books and OpenLibrary
            book_data = fetch_book_details(isbn)
            if not book_data:
                return "Book not found. Please check the ISBN or enter details manually."

            return render_template(
                "add_book.html",
                isbn=isbn,
                title=book_data.get("title", ""),
                authors=", ".join(book_data.get("authors", [])),
                year=book_data.get("publishedDate", ""),
                description=book_data.get("description", ""),
                thumbnail_url=book_data.get("thumbnail", ""),
                subjects=", ".join(book_data.get("subjects", [])),
                number_of_pages=book_data.get("number_of_pages", ""),
                openlibrary_preview_url=book_data.get("preview_link", ""),
                location_form=location_form,  # Pass location form with choices
            )

        elif "submit_book" in request.form:  # Handle form submission
           # Check if the book already exists by ISBN
            isbn = request.form.get("isbn")
            existing_book = Book.query.filter_by(isbn=isbn).first()
            if existing_book:
                flash("This book already exists in the system. Redirecting to its details page.", "info")
                return redirect(url_for("detail", id=existing_book.id))  # Redirect to the existing book's detail page

            title=request.form.get("title", "").strip()
            authors=request.form.get("authors", "").strip()
            # Handle location selection
            location_id = request.form.get("location")
            location_id = int(location_id) if location_id and location_id != "-1" else None
            if not title or not authors or not location_id:
                flash("Title, Authors, and Location are required fields!", "danger")
                return redirect(url_for('add_book'))

            # Save the book to the database
            book = Book(
                isbn=request.form.get("isbn", "").strip(),
                title=title,
                authors=authors,
                publish_date=request.form.get("year", "").strip(),
                subjects=request.form.get("subjects", "").strip(),
                openlibrary_medcover_url=request.form.get("thumbnail_url", "").strip(),
                openlibrary_preview_url=request.form.get("preview_link", "").strip(),
                olid=request.form.get("openlibrary_link", "").strip(),
                number_of_pages=request.form.get("number_of_pages", "").strip(),
                dewey_decimal_class="",  # Not used
                lccn="", # not used
                location=location_id,
            )
            db.session.add(book)
            db.session.commit()

            # Store all book details in JSON format
            location = Location.query.get(book.location)
            location_label = f"{location.label_name}, {location.full_name}" if location else "Unknown"
            book_data = {
                "isbn": book.isbn,
                "title": book.title,
                "authors": book.authors,
                "publish_date": book.publish_date,
                "subjects": book.subjects,
                "pages": book.number_of_pages,
                "openlibrary_preview_url": book.openlibrary_preview_url,
                "thumbnail": book.openlibrary_medcover_url,
                "location_id": book.location,
                "location_label": location_label,
            }
            transaction = TransactionLog(
                action="ADD",
                book_id=book.id,
                book_title=f"{book.authors} - {book.title}",
                details=json.dumps(book_data)
            )
            db.session.add(transaction)
            db.session.commit()

            return redirect(url_for("detail", id=book.id))

    # locations = LibraryLocation.query.all()  # Fetch available library locations
    return render_template("add_book.html", location_form=location_form)


@app.route("/edit_book/<int:id>", methods=["GET", "POST"])
def edit_book(id):
    """Edit an existing book's details with an ISBN search option."""
   # Check if user is logged in
    auth_redirect = login_required()
    if auth_redirect:
        return auth_redirect  # Redirect user if not logged in

    book = Book.query.get(id)
    if book is None:
        flash(f"Book with ID {id} does not exist.", "danger")
        return redirect(url_for("index", page=1))

    # Fetch available locations
    locations = Location.query.order_by("label_name").all()
    location_choices = [(l.id, f"{l.label_name}, {l.full_name}") for l in locations]

    if request.method == "POST":
        # Fetch book details by ISBN and overwrite fields only if they have meaningful data
        if "search_isbn" in request.form:
            isbn = str(request.form.get("isbn", "")).strip()
            if not check_isbn(isbn):
                flash("Invalid ISBN. Please enter a valid 10 or 13-digit ISBN.", "danger")
                return redirect(url_for("edit_book", id=book.id))

            book_data = fetch_book_details(isbn)
            if not book_data:
                flash("Book not found. Please enter details manually.", "warning")
                return redirect(url_for("edit_book", id=book.id))

            # Set ISBN, in case it was missing in the DB
            book.isbn = isbn
            # Only overwrite fields if they contain meaningful data
            if book_data.get("title"): book.title = book_data["title"]
            if book_data.get("authors"): book.authors = ", ".join(book_data.get("authors", []))
            if book_data.get("publish_date"): book.publish_date = book_data["publish_date"]
            if book_data.get("subjects"): book.subjects = ", ".join(book_data.get("subjects", []))
            if book_data.get("thumbnail"): book.openlibrary_medcover_url = book_data["thumbnail"]
            if book_data.get("preview_link"): book.openlibrary_preview_url = book_data["preview_link"]
            if book_data.get("number_of_pages"): book.number_of_pages = book_data["number_of_pages"]

            flash("Book details updated from ISBN search!", "info")
            return render_template("edit_book.html", book=book, locations=location_choices)

        # update the book details
        elif "submit_book" in request.form:
            # Ensure ISBN is unique (excluding the current book)
            isbn = str(request.form.get("isbn", "")).strip()
            existing_book = Book.query.filter(Book.isbn == isbn, Book.id != book.id).first()
            if existing_book:
                flash("A book with this ISBN already exists.", "danger")
                return redirect(url_for("detail", id=existing_book.id))

            # Save previous state for logging
            old_data = book.__dict__.copy()

            # Update book details from form
            book.isbn = isbn
            book.title = request.form.get("title", "").strip()
            book.authors = request.form.get("authors", "").strip()
            book.publish_date = request.form.get("year", "").strip()
            book.subjects = request.form.get("description", "").strip()
            book.openlibrary_medcover_url = request.form.get("thumbnail_url", "").strip()
            book.openlibrary_preview_url = request.form.get("openlibrary_preview_url", "").strip()
            book.number_of_pages = request.form.get("number_of_pages", "").strip()

            # Handle location selection
            location_id = request.form.get("location")
            location_id = int(location_id) if location_id and location_id != "-1" else None

            # for logging location changes
            old_location_id = book.location
            old_location = Location.query.get(old_location_id)
            old_location_label = f"{old_location.label_name}, {old_location.full_name}" if old_location else "Unknown"
            new_location = Location.query.get(location_id)
            new_location_label = f"{new_location.label_name}, {new_location.full_name}" if new_location else "Unknown"

            book.location = location_id
            db.session.commit()

            # Log the transaction
            changes = []
            for key in ["isbn", "title", "authors", "publish_date", "subjects", "number_of_pages",
                        "openlibrary_medcover_url", "openlibrary_preview_url"]:
                old_value = old_data.get(key, "")
                new_value = getattr(book, key, "")
                if old_value != new_value:
                    changes.append(f"{key}: '{old_value}' → '{new_value}'")

            # Log location change
            if old_location_id != location_id:
                changes.append(f"Location: '{old_location_label}' (ID: {old_location_id}) → '{new_location_label}' (ID: {location_id})")

            transaction = TransactionLog(
                action="EDIT",
                book_id=book.id,
                book_title=f"{book.authors} - {book.title}",
                details="; ".join(changes) if changes else "No changes detected."
            )
            db.session.add(transaction)
            db.session.commit()

            flash("Book details updated successfully!", "success")
            return redirect(url_for("detail", id=book.id))

    return render_template("edit_book.html", book=book, locations=location_choices)


@app.route("/delete_book/<int:id>", methods=["POST"])
def delete_book(id):
    """Delete a book from the database."""
    auth_redirect = login_required()
    if auth_redirect:
        return auth_redirect

    book = Book.query.get(id)
    if book is None:
        flash(f"Book with ID {id} does not exist.", "danger")
        return redirect(url_for("index", page=1))

    # Log full book details before deleting
    # Retrieve location details
    location = Location.query.get(book.location)
    location_label = f"{location.label_name}, {location.full_name}" if location else "Unknown"
    # Store all book details in JSON format
    book_data = {
        "isbn": book.isbn,
        "title": book.title,
        "authors": book.authors,
        "publish_date": book.publish_date,
        "subjects": book.subjects,
        "pages": book.number_of_pages,
        "openlibrary_preview_url": book.openlibrary_preview_url,
        "thumbnail": book.openlibrary_medcover_url,
        "location_id": book.location,
        "location_label": location_label,
    }
    transaction = TransactionLog(
        action="DELETE",
        book_id=book.id,
        book_title=f"{book.authors} - {book.title}",
        details=json.dumps(book_data)  # Convert to JSON string
    )
    db.session.add(transaction)
    db.session.commit()

    db.session.delete(book)
    db.session.commit()

    flash("Book deleted successfully!", "success")
    return redirect(url_for("index", page=1))


@app.route("/restore_book/<int:log_id>", methods=["POST"])
def restore_book(log_id):
    auth_redirect = login_required()
    if auth_redirect:
        return auth_redirect

    log_entry = TransactionLog.query.get(log_id)
    if not log_entry or log_entry.action != "DELETE":
        flash("Invalid log entry for restoration.", "danger")
        return redirect(url_for("view_logs"))

    # Load JSON data
    try:
        book_data = json.loads(log_entry.details)
    except json.JSONDecodeError:
        flash("Error decoding book data from log.", "danger")
        return redirect(url_for("view_logs"))

    # Restore the book
    book = Book(
        isbn=book_data.get("isbn", ""),
        title=book_data.get("title", ""),
        authors=book_data.get("authors", ""),
        publish_date=book_data.get("publish_date", ""),
        subjects=book_data.get("subjects", ""),
        number_of_pages=book_data.get("pages", ""),
        openlibrary_preview_url=book_data.get("openlibrary_preview_url", ""),
        openlibrary_medcover_url=book_data.get("thumbnail", ""),
        location=book_data.get("location_id"),
        dewey_decimal_class="",  # Not used
        lccn="", # not used
        olid="", # not used
    )

    db.session.add(book)
    db.session.commit()

    transaction = TransactionLog(
        action="RESTORE",
        book_id=book.id,
        book_title=f"{book.authors} - {book.title}",
        details=f"Restored from a DELETE ({log_entry.timestamp})"
        )
    db.session.add(transaction)
    db.session.commit()

    flash(f"Book '{book.title}' has been restored!", "success")
    # return redirect(url_for("detail", id=book.id))
    return redirect(url_for("view_logs"))


@app.route("/logs")
def view_logs():
    logs = TransactionLog.query.order_by(TransactionLog.timestamp.desc()).all()
    return render_template("logs.html", logs=logs)


@app.route("/detail/<int:id>", methods=["GET", "POST"])
def detail(id=1):
    """Show an individual work"""

    book = Book.query.get(id)
    if book is None:
        flash(f"Book with ID {id} does not exist.", "danger")
        return redirect(url_for("index", page=1))

    # Fetch available locations
    locations = Location.query.order_by("label_name").all()

    # Set the location to be displayed
    location_display = None
    if book.location:
        location_display = next((l for l in locations if l.id == book.location), None)

    return render_template(
        "detail.html", book=book, location_display=location_display
    )


@app.route("/index/<int:page>", methods=["GET", "POST"])
def index(page=1):
    """Show an index of books, provide some basic searchability."""

    if request.method == "POST":
        s = request.form["search"]
        return redirect(url_for("index", page=1, s=s))

    # Get the search term and number of items per page from the request
    s = request.args.get("s")
    per_page = request.args.get("per_page", PAGINATE_BY_HOWMANY, type=int)
    sort_by = request.args.get("sort_by", "title")  # Default sort by title
    sort_order = request.args.get("sort_order", "asc")  # Default order is ascending

    # Set sorting direction (ascending or descending)
    if sort_order == "asc":
        sort_direction = asc
    else:
        sort_direction = desc

    # Create the query to select books
    query = db.session.query(Book, Location).join(Location, Book.location == Location.id)
   # Apply filtering if a search term is provided
    if s:
        query = query.filter(
            or_(
                Book.title.contains(s),
                Book.authors.contains(s),
                Book.subjects.contains(s),
                Book.isbn.contains(s),
            )
        )

    # Apply sorting based on the 'sort_by' and 'sort_order' parameters
    query = query.order_by(sort_direction(getattr(Book, sort_by)))

    # Execute the pagination
    books = query.paginate(page=page, per_page=per_page, error_out=False)

    return render_template("index.html", books=books, s=s, sort_by=sort_by, sort_order=sort_order, per_page=per_page)


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]

        if username == USER['username'] and password == USER['password']:
            session["logged_in"] = True
            flash("Login successful!", "success")
            return redirect(url_for("index", page=1))
        else:
            flash("Invalid username or password.", "danger")

    return render_template("login.html")


@app.route("/logout")
def logout():
    session.pop("logged_in", None)
    flash("You have been logged out.", "info")
    return redirect(url_for("index", page=1))


if __name__ == "__main__":
    # flask can execute arbitrary python if you do this.
    # app.run(host='0.0.0.0') # listens on all public IPs.

    app.run()
