from setuptools import setup, find_packages

with open('requirements.txt') as f:
    install_requires = f.read().splitlines()

setup(
    name="library-org",
    version="0.1.0",
    author="Paw Møller",
    description="A Flask-based library management system.",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/pawsen/library-org",
    packages=find_packages(where="src"),  # Only look for packages in the `src` directory
    package_dir={"": "src"},  # Map the root package to the `src` directory
    include_package_data=True,  # Include non-Python files (e.g., templates, static files)
    install_requires=install_requires,
    python_requires=">=3.10",
    entry_points={
        "console_scripts": [
            "library-org = src.controller:app",  # Entry point for running the app
        ],
    },
)
