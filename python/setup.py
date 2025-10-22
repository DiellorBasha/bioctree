"""
Setup script for Bioctree Python package.

Installation:
    pip install -e .

Or for development:
    pip install -e .[dev]
"""

from setuptools import setup, find_packages
import os

# Read requirements
def read_requirements(filename):
    with open(filename, 'r') as f:
        return [line.strip() for line in f if line.strip() and not line.startswith('#')]

# Read long description
def read_long_description():
    with open('README.md', 'r', encoding='utf-8') as f:
        return f.read()

# Core requirements
requirements = [
    'numpy>=1.20.0',
    'scipy>=1.7.0',
    'matplotlib>=3.3.0',
    'networkx>=2.5',
    'scikit-learn>=1.0.0',
]

# Optional requirements
extras_require = {
    'full': [
        'pygsp>=0.5.1',
        'plotly>=5.0.0',
        'h5py>=3.0.0',
        'seaborn>=0.11.0',
    ],
    'jupyter': [
        'jupyter>=1.0.0',
        'ipywidgets>=7.6.0',
    ],
    'dev': [
        'pytest>=6.0.0',
        'pytest-cov>=2.10.0',
        'black>=21.0.0',
        'flake8>=3.8.0',
    ]
}

setup(
    name='bioctree-py',
    version='1.0.0',
    author='Bioctree Development Team',
    author_email='developer@bioctree.org',
    description='Graph Signal Processing for Neuroscience - Python Implementation',
    long_description=read_long_description() if os.path.exists('README.md') else '',
    long_description_content_type='text/markdown',
    url='https://github.com/DiellorBasha/bioctree',
    packages=find_packages(),
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
        'Topic :: Scientific/Engineering :: Mathematics',
        'Topic :: Scientific/Engineering :: Medical Science Apps.',
    ],
    python_requires='>=3.8',
    install_requires=requirements,
    extras_require=extras_require,
    entry_points={
        'console_scripts': [
            'bioctree-demo=bioctree_py.demos.demo_bunny_pipeline:main',
        ],
    },
    include_package_data=True,
    zip_safe=False,
)