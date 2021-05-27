### Library Organization Project

##### Project Status

Missing features
- manual `create a new book` page. The current way to create a new entry, is to `submit-by-isbn` which tries retrieve info about a book from google-books and openlibrary.org.
- upload files(pdf) which then can be found from the `index` page,
- some kind of textual mapping of location, ie. `2.12` is `Asia`.

##### Getting Started
- fork and clone this repository
- install in a virtual env. or run the docker-compose file
ie.
``` sh
pip install -r requirements.txt
FLASK_APP=controller.py python src/manage.py run  # or
python src/controller.py
```
OR 

``` sh
docker-compose up -d  # or for production
docker-compose up -d -f docker-compose.prod.yml
```
- go to [localhost:5000] (http://localhost:5000) in the browser

