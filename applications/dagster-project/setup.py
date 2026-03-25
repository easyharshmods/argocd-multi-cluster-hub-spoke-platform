from setuptools import setup, find_packages

setup(
    name="dagster_project",
    packages=find_packages(exclude=["tests"]),
    install_requires=[
        "dagster>=1.9.11",
        "dagster-webserver>=1.9.11",
        "dagster-k8s>=0.25.11",
        "dagster-postgres>=0.25.11",
        "dagster-aws>=0.25.11",
        "pandas>=2.2.3",
        "requests>=2.32.3",
        "psycopg2-binary>=2.9.10",
        "boto3>=1.35.90",
    ],
    extras_require={
        "dev": [
            "pytest>=8.3.4",
            "pytest-cov>=6.0.0",
        ]
    },
)
