import setuptools

setuptools.setup(
    name="sample-app",
    version="1.0",
    description="Sample application to run on k8s cluster",
    packages=setuptools.find_packages(),
    package_data={"app": ["resources/data/*.csv"]}
)
