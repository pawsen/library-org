FROM python:3.11-slim-buster

# PYTHONUNBUFFERED: Prevents Python from buffering stdout and stderr (equivalent
# to python -u option)
# PYTHONDONTWRITEBYTECODE: Prevents Python from writing pyc files to disc
# (equivalent to python -B
# https://docs.python.org/3/using/cmdline.html#cmdoption-u
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH=/code/src/:$PYTHONPATH

WORKDIR /code
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY library.cfg .
COPY src .

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0"]
