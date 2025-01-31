FROM python:3.11-slim-buster

# PYTHONUNBUFFERED: Prevents Python from buffering stdout and stderr (equivalent
# to python -u option)
# PYTHONDONTWRITEBYTECODE: Prevents Python from writing pyc files to disc
# (equivalent to python -B
# https://docs.python.org/3/using/cmdline.html#cmdoption-u
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH=/app/src/:$PYTHONPATH

# Set the working directory inside the container
WORKDIR /app

# Copy only necessary files to leverage Docker cache
COPY requirements.txt /app/
COPY src /app/src/

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port the Flask app runs on
EXPOSE 5000

# this is the only way I can get docker to listen to all interfaces, whitout
# changing controller.py
# even if I specify `docker run ... -e FLASK_RUN_HOST=0.0.0.0 ..` it still only
# listen to 127.0.0.1`
# CMD ["python", "src/controller.py"] ## XXX does not work, just for ref.
#
# GET DEBUG INFO
# ENV FLASK_APP=controller.py
# CMD ["python", "-m", "flask", "run", "--host=0.0.0.0"]
#
# PRODUCTION
CMD ["gunicorn", "src:app", "-b 0.0.0.0:5000"]

# use like
# docker build -t library .
# docker run -p 5000:5000 \
#          -v "$(pwd)/database:/app/database" \
#          -v "$(pwd)/uploads:/app/uploads" \
#          -v "$(pwd)/library.cfg:/app/library.cfg" \
#          library:latest
