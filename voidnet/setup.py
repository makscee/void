from setuptools import setup, find_packages

setup(
    name="voidnet",
    version="0.1.0",
    packages=find_packages(),
    package_data={
        "voidnet": ["uplink/*.py", "uplink/requirements.txt"],
    },
    install_requires=[
        "typer>=0.9.0",
        "pyyaml>=6.0",
        "httpx>=0.25.0",
        "rich>=13.0",
    ],
    python_requires=">=3.8",
    entry_points={
        "console_scripts": [
            "voidnet=voidnet.cli:main",
        ],
    },
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
)
