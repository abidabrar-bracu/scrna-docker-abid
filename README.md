# scanalysis-base (scrna-docker)

GPU-enabled single-cell analysis base image (Python + R) for **Scanpy / scvi-tools / Seurat v5 / Monocle 3** workflows.

## Tags
See [`tags.yaml`](./tags.yaml) for published versions.

## Build & Push

**Docker Hub**
```bash
export DOCKERHUB_USER=abidabrar
./build.sh 1.0.0 dockerhub
```

**GitHub Container Registry (GHCR)**
```bash
export GH_USER=abidabrar-bracu
# login once: echo $GH_TOKEN | docker login ghcr.io -u $GH_USER --password-stdin
./build.sh 1.0.0 ghcr
```

**Local Build**
```bash
./build.sh 1.0.0 local
```
---
# Use locally (Docker)
**Example 1**: bind current directory to `/workspace`
```bash
docker run --gpus all -it \
  -p 8888:8888 \
  -v "$PWD":/workspace -w /workspace \
  abidabrar/scanalysis-base:1.0.0

  # then inside:
  # jupyter lab --ip=0.0.0.0 --no-browser --port=8888
```
**Example 2**: bind code + data separately:
```bash
docker run --gpus all -it \
  -p 8888:8888 \
  -v /path/to/code:/workspace -w /workspace \
  -v /path/to/data:/workspace/data \
  abidabrar/scanalysis-base:1.0.0
```
> [!NOTE]  
> The image creates /workspace and assigns it to the non-root vscode user for consistent write access.
> If you’re on Apple Silicon and see an arch warning, add --platform linux/amd64.

---

# Use on HPC (Apptainer/Singularity)
## 0) Pull the image as a .sif
```bash
# Docker Hub
singularity pull scanalysis-base.sif docker://abidabrar/scanalysis-base:latest
```
> [!TIP]
> put SIFs in a shared location (e.g., `/mount/USER/containers/`).
> You can set export `SINGULARITY_CACHEDIR=/path/to/big/scratch` to avoid home-quota limitation.

## 1) Interactive shell (recommended for quick work)
```bash
# Get a compute node
salloc --cpus-per-task=8 --mem=32G
  # or with GPU:
  # salloc --cpus-per-task=8 --mem=32G --partition=gpu --constraint=rtx5000 --gres=gpu:1

# Inside the allocation:
cd /path/to/project

# Bind code and (optionally) data, enable GPUs with --nv
singularity exec --nv \
  -B $PWD:/workspace \
  -B /path/to/data:/workspace/data \
  scanalysis-base_1.0.0.sif \
  bash
 
# Now you'are inside the container:
# python / R / jupyter available here
```
> [!NOTE]  
> Add `--cleanenv` if local modules or environment variables interfere.
> Use multiple `-B` flags to bind extra paths as needed.

## 2) Run scripts (batch-friendly)
Use the following commands as examples and put them into your Slurm job scripts, just like you would to run. Python/R nomrally.
#### Python
```bash
singularity exec --nv \
  -B $PWD:/workspace \
  -B /path/to/data:/workspace/data \
  scanalysis-base_1.0.0.sif \
  python scripts/analyze.py --config /workspace/data/conf.yaml
```
#### R
```bash
singularity exec --nv \
  -B $PWD:/workspace \
  scanalysis-base_1.0.0.sif \
  Rscript scripts/analysis.R
```

## 3) Jupyter Lab/Notebook on a compute node (two ways)
### A) Interactive (salloc) + SSH tunnel
1. Start Jupyter inside the container:
```bash
# first get an interactive slurm job
salloc --cpus-per-task=8 --mem=32G --partition=gpu --constraint=rtx5000 --gres=gpu:1

# start jupyter with port forwarding
PORT=8888
singularity exec --nv -B $PWD:/workspace scanalysis-base_1.0.0.sif \
  jupyter lab --ip=0.0.0.0 --no-browser --port=$PORT
```
2. On your **laptop**, open a **new** terminal window and forward the port from `localhost` through the login node to the compute node (replace placeholders):
```bash
# Find compute node name from the Jupyter log, e.g., compute-1-23
ssh -L 8888:compute-1-23:8888 USER@hpc.login.address
# open http://localhost:8888 or http://127.0.0.1 in your laptop browser and paste the token
```
### B) Slurm batch Jupyter (long sessions, preferred method)
1. Create a `jupyter.sbatch` script. Example:
```bash
#!/bin/bash
#SBATCH --job-name=jlab
#SBATCH --partition=gpu
#SBATCH --constraint=rtx5000
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=jupyter-%J.log
#SBATCH --error=jupyter-%J.log

PORT=8888
SIF="/mount/${USER}/containers/scanalysis-base_1.0.0.sif"
WORKDIR=/path/to/code

source ~/.bashrc

echo "Compute node: $(hostname)"
echo "Using port: ${PORT}"
echo "SIF: ${SIF}"
echo "Workdir: ${WORKDIR}"

singularity exec --nv -B ${WORKDIR}:/workspace ${SIF} \
  jupyter lab --ip=0.0.0.0 --no-browser --port ${PORT}
```
2. Submit the job:
```bash
sbatch jupyter.sbatch
```
3. Then
    - `squeue -u $USER` → find the node in the log (jupyter-<JOBID>.log) and the Jupyter URL/token.
    - On your laptop, tunnel as in the interactive example, using that compute node + port.

---
# Notes
- Torch: 2.4.1 + CUDA 12.1
- R: CRAN 4.4 (Ubuntu Jammy)
- Python: scanpy, scvi-tools, squidpy, spatialdata, etc.
- R: Seurat (v5.3.0), SeuratObject, seurat-wrappers, Monocle 3, BPCells, anndataR, etc

# Known issues
AnnData changed anndata.read. If `scarches` import fails:

```python
import anndata as ad
ad.read = ad.read_h5ad
import scarches # should work now
```
<!--VERSIONS_START-->

# Installed library versions (latest build)

<details><summary><b>Python stack</b></summary>

```text
Brotli:                         1.1.0
Cython:                         3.1.4
Deprecated:                     1.2.18
FlowIO:                         1.4.0
HeapDict:                       1.0.1
Jinja2:                         3.1.4
Markdown:                       3.9
MarkupSafe:                     2.1.5
NaiveDE:                        1.2.0
PIMS:                           0.7
Pint:                           0.25
PubChemPy:                      1.0.5
PyOpenGL:                       3.1.10
PyQt5:                          5.15.11
PyQt5-Qt5:                      5.15.17
PyQt5_sip:                      12.17.1
PySocks:                        1.7.1
PyYAML:                         6.0.2
Pygments:                       2.18.0
QtPy:                           2.4.3
Send2Trash:                     1.8.3
SpatialDE:                      1.1.3
Sphinx:                         8.2.3
Werkzeug:                       3.1.3
absl-py:                        2.3.1
adjustText:                     1.3.0
aiobotocore:                    2.25.0
aiohappyeyeballs:               2.6.1
aiohttp:                        3.13.1
aioitertools:                   0.12.0
aiosignal:                      1.4.0
alabaster:                      1.0.0
anndata:                        0.12.3
anndata2ri:                     2.0
annotated-types:                0.7.0
annoy:                          1.17.3
anyio:                          4.11.0
app-model:                      0.4.0
appdirs:                        1.4.4
archspec:                       0.2.3
argon2-cffi:                    25.1.0
argon2-cffi-bindings:           25.1.0
array-api-compat:               1.12.0
arrow:                          1.4.0
arviz:                          0.22.0
asciitree:                      0.3.3
asttokens:                      2.4.1
astunparse:                     1.6.3
async-lru:                      2.0.5
attrs:                          24.2.0
babel:                          2.17.0
bbknn:                          1.6.0
beautifulsoup4:                 4.12.3
bleach:                         6.2.0
blitzgsea:                      1.3.54
boltons:                        24.0.0
botocore:                       1.40.49
build:                          1.3.0
cachey:                         0.2.1
celltypist:                     1.7.1
cellxgene-census:               1.17.0
certifi:                        2024.8.30
cffi:                           1.17.0
chardet:                        5.2.0
charset-normalizer:             3.3.2
chex:                           0.1.86
click:                          8.1.7
cloudpickle:                    3.1.1
colorama:                       0.4.6
colorcet:                       3.1.0
comm:                           0.2.3
conda:                          24.7.1
conda-build:                    24.7.1
conda-libmamba-solver:          24.7.0
conda-package-handling:         2.3.0
conda_index:                    0.5.0
conda_package_streaming:        0.10.0
contourpy:                      1.3.3
cycler:                         0.12.1
dask:                           2024.11.2
dask-expr:                      1.1.19
dask-image:                     2024.5.3
datashader:                     0.18.2
debugpy:                        1.8.17
decorator:                      5.1.1
decoupler:                      2.1.1
defusedxml:                     0.7.1
distro:                         1.9.0
dnspython:                      2.6.1
docrep:                         0.3.2
docstring_parser:               0.17.0
docutils:                       0.21.2
equinox:                        0.11.10
et_xmlfile:                     2.0.0
etils:                          1.13.0
exceptiongroup:                 1.2.2
executing:                      2.1.0
expecttest:                     0.2.1
fast-array-utils:               1.2.5
fasteners:                      0.20
fastjsonschema:                 2.21.2
filelock:                       3.15.4
flax:                           0.8.4
flexcache:                      0.3
flexparser:                     0.4
fonttools:                      4.60.1
fqdn:                           1.5.1
freetype-py:                    2.5.1
frozendict:                     2.4.4
frozenlist:                     1.8.0
fsspec:                         2025.9.0
funsor:                         0.4.5
gdown:                          5.2.0
geopandas:                      1.1.1
grpcio:                         1.75.1
h11:                            0.16.0
h2:                             4.1.0
h5netcdf:                       1.7.2
h5py:                           3.15.1
harmonypy:                      0.0.10
hpack:                          4.0.0
hsluv:                          5.0.4
httpcore:                       1.0.9
httpx:                          0.28.1
hyperframe:                     6.0.1
hypothesis:                     6.111.2
idna:                           3.8
igraph:                         0.11.9
imagecodecs:                    2025.8.2
imageio:                        2.37.0
imagesize:                      1.4.1
importlib_metadata:             8.7.0
importlib_resources:            6.4.4
in-n-out:                       0.2.1
inflect:                        7.5.0
ipykernel:                      6.30.1
ipython:                        8.27.0
ipython_pygments_lexers:        1.1.1
isoduration:                    20.11.0
jax:                            0.4.21
jaxlib:                         0.8.0
jaxopt:                         0.8.5
jaxtyping:                      0.3.3
jedi:                           0.19.1
jmespath:                       1.0.1
joblib:                         1.5.2
json5:                          0.12.1
jsonpatch:                      1.33
jsonpointer:                    3.0.0
jsonschema:                     4.23.0
jsonschema-specifications:      2023.12.1
jupyter-events:                 0.12.0
jupyter-lsp:                    2.3.0
jupyter_client:                 8.6.3
jupyter_core:                   5.9.1
jupyter_server:                 2.17.0
jupyter_server_terminals:       0.5.3
jupyterlab:                     4.4.9
jupyterlab_pygments:            0.3.0
jupyterlab_server:              2.27.3
kiwisolver:                     1.4.9
lamin_utils:                    0.15.0
lazy_loader:                    0.4
legacy-api-wrap:                1.4.1
legendkit:                      0.3.6
leidenalg:                      0.10.2
liana:                          1.6.1
libarchive-c:                   5.1
libmambapy:                     1.5.9
lief:                           0.14.1
lightning:                      2.5.5
lightning-utilities:            0.15.2
lineax:                         0.0.4
lintrunner:                     0.12.5
llvmlite:                       0.45.1
locket:                         1.0.0
loguru:                         0.7.3
loompy:                         3.0.8
magicgui:                       0.10.1
makefun:                        1.16.0
mamba:                          1.5.9
markdown-it-py:                 4.0.0
marsilea:                       0.5.6
matplotlib:                     3.10.7
matplotlib-inline:              0.1.7
matplotlib-scalebar:            0.9.0
mdurl:                          0.1.2
menuinst:                       2.1.2
mistune:                        3.1.4
mizani:                         0.14.2
ml_collections:                 1.1.0
ml_dtypes:                      0.5.3
more-itertools:                 10.4.0
mpmath:                         1.3.0
msgpack:                        1.1.2
mudata:                         0.3.2
multidict:                      6.7.0
multipledispatch:               1.0.0
multiscale_spatial_image:       2.0.3
muon:                           0.1.7
napari:                         0.6.6
napari-console:                 0.1.4
napari-matplotlib:              3.0.0
napari-plugin-engine:           0.2.0
napari-spatialdata:             0.5.7
napari-svg:                     0.2.1
natsort:                        8.4.0
nbclient:                       0.10.2
nbconvert:                      7.16.6
nbformat:                       5.10.4
nest-asyncio:                   1.6.0
networkx:                       3.3
newick:                         1.0.0
ninja:                          1.11.1.1
notebook:                       7.4.7
notebook_shim:                  0.2.4
npe2:                           0.7.9
numba:                          0.62.1
numcodecs:                      0.15.1
numpy:                          2.1.1
numpy-groupies:                 0.11.3
numpydoc:                       1.9.0
numpyro:                        0.15.0
nvidia-cublas-cu12:             12.1.3.1
nvidia-cuda-cupti-cu12:         12.1.105
nvidia-cuda-nvrtc-cu12:         12.1.105
nvidia-cuda-runtime-cu12:       12.1.105
nvidia-cudnn-cu12:              9.1.0.70
nvidia-cufft-cu12:              11.0.2.54
nvidia-curand-cu12:             10.3.2.106
nvidia-cusolver-cu12:           11.4.5.107
nvidia-cusparse-cu12:           12.1.0.106
nvidia-nccl-cu12:               2.20.5
nvidia-nvjitlink-cu12:          12.1.105
nvidia-nvtx-cu12:               12.1.105
ome-types:                      0.6.2
ome-zarr:                       0.11.1
omnipath:                       1.0.12
openpyxl:                       3.1.5
opt_einsum:                     3.4.0
optax:                          0.2.2
optree:                         0.12.1
orbax-checkpoint:               0.5.16
ott-jax:                        0.4.6
overrides:                      7.7.0
packaging:                      25.0
pandas:                         2.3.3
pandocfilters:                  1.5.1
param:                          2.2.1
parso:                          0.8.4
partd:                          1.4.2
patsy:                          1.0.1
pertpy:                         1.0.3
pexpect:                        4.9.0
pickleshare:                    0.7.5
pillow:                         10.2.0
pip:                            24.2
pkginfo:                        1.11.1
pkgutil_resolve_name:           1.3.10
platformdirs:                   4.2.2
plotnine:                       0.15.0
plottable:                      0.1.5
pluggy:                         1.5.0
ply:                            3.11
pooch:                          1.8.2
prometheus_client:              0.23.1
prompt_toolkit:                 3.0.47
propcache:                      0.4.1
protobuf:                       6.33.0
psutil:                         6.0.0
psygnal:                        0.15.0
ptyprocess:                     0.7.0
pure_eval:                      0.2.3
pyarrow:                        21.0.0
pyarrow-hotfix:                 0.7
pyconify:                       0.2.1
pycosat:                        0.6.6
pycparser:                      2.22
pyct:                           0.6.0
pydantic:                       2.12.3
pydantic-compat:                0.1.2
pydantic-extra-types:           2.10.6
pydantic_core:                  2.41.4
pydot:                          4.0.1
pynndescent:                    0.5.13
pyogrio:                        0.11.1
pyomo:                          6.9.5
pyparsing:                      3.2.5
pyproj:                         3.7.2
pyproject_hooks:                1.2.0
pyqtgraph:                      0.13.7
pyro-api:                       0.1.2
pyro-ppl:                       1.9.1
python-dateutil:                2.9.0.post0
python-etcd:                    0.4.5
python-json-logger:             4.0.0
pytorch-lightning:              2.5.5
pytz:                           2024.1
pyzmq:                          27.1.0
qtconsole:                      5.7.0
readfcs:                        2.0.1
referencing:                    0.35.1
requests:                       2.32.3
rfc3339-validator:              0.1.4
rfc3986-validator:              0.1.1
rich:                           14.2.0
roman-numerals-py:              3.1.0
rpds-py:                        0.20.0
rpy2:                           3.6.4
rpy2-rinterface:                3.6.3
rpy2-robjects:                  3.6.3
ruamel.yaml:                    0.18.6
ruamel.yaml.clib:               0.2.8
s3fs:                           2025.9.0
scArches:                       0.6.1
scHPL:                          1.0.3
scanpy:                         1.11.4
scib:                           1.1.7
scib-metrics:                   0.5.7
scikit-image:                   0.25.2
scikit-learn:                   1.7.2
scikit-misc:                    0.5.1
scipy:                          1.15.3
scvelo:                         0.3.3
scvi-tools:                     1.4.0
seaborn:                        0.13.2
session-info2:                  0.2.3
setuptools:                     73.0.1
shapely:                        2.1.2
shellingham:                    1.5.4
six:                            1.16.0
slicerator:                     1.1.0
sniffio:                        1.3.1
snowballstemmer:                3.0.1
somacore:                       1.0.29
sortedcontainers:               2.4.0
soupsieve:                      2.5
sparse:                         0.17.0
sparsecca:                      0.3.1
spatial_image:                  1.2.3
spatialdata:                    0.5.0
spatialdata-io:                 0.3.0
spatialdata-plot:               0.2.12
sphinxcontrib-applehelp:        2.0.0
sphinxcontrib-devhelp:          2.0.0
sphinxcontrib-htmlhelp:         2.1.0
sphinxcontrib-jsmath:           1.0.1
sphinxcontrib-qthelp:           2.0.0
sphinxcontrib-serializinghtml:  2.0.0
squidpy:                        1.6.5
stack-data:                     0.6.2
statsmodels:                    0.14.5
superqt:                        0.7.6
sympy:                          1.13.2
tangram-sc:                     1.0.4
tensorboard:                    2.20.0
tensorboard-data-server:        0.7.2
tensorstore:                    0.1.78
terminado:                      0.18.1
texttable:                      1.7.0
threadpoolctl:                  3.6.0
tifffile:                       2025.10.16
tiledbsoma:                     2.1.0
tinycss2:                       1.4.0
tomli_w:                        1.2.0
toolz:                          1.1.0
torch:                          2.4.1+cu121
torchaudio:                     2.4.1+cu121
torchelastic:                   0.2.2
torchmetrics:                   1.8.2
torchvision:                    0.19.1+cu121
tornado:                        6.5.2
tqdm:                           4.66.5
traitlets:                      5.14.3
triton:                         3.0.0
truststore:                     0.9.2
typeguard:                      4.4.4
typer:                          0.19.2
types-dataclasses:              0.6.6
typing-inspection:              0.4.2
typing_extensions:              4.15.0
tzdata:                         2025.2
tzlocal:                        5.3.1
umap-learn:                     0.5.9.post2
uri-template:                   1.3.0
urllib3:                        2.2.2
validators:                     0.35.0
vispy:                          0.15.2
wadler_lindig:                  0.1.7
wcwidth:                        0.2.13
webcolors:                      24.11.1
webencodings:                   0.5.1
websocket-client:               1.9.0
wheel:                          0.44.0
wrapt:                          1.17.3
xarray:                         2025.10.1
xarray-dataclass:               3.0.0
xarray-datatree:                0.0.14
xarray-einstats:                0.9.1
xarray-schema:                  0.0.3
xarray-spatial:                 0.4.0
xsdata:                         25.7
yarl:                           1.22.0
zarr:                           2.18.7
zipp:                           3.20.1
zstandard:                      0.23.0
```
</details>

<details><summary><b>R stack</b></summary>

```text
Package                      Version
AnnotationDbi                1.70.0
AnnotationFilter             1.32.0
Azimuth                      0.5.0
BH                           1.87.0-1
BPCells                      0.3.1
BSgenome                     1.76.0
BSgenome.Hsapiens.UCSC.hg38  1.4.5
Biobase                      2.68.0
BiocGenerics                 0.54.1
BiocIO                       1.18.0
BiocManager                  1.30.26
BiocNeighbors                2.2.0
BiocParallel                 1.42.2
BiocSingular                 1.24.0
Biostrings                   2.76.0
Cairo                        1.6-5
CellChat                     2.2.0
ComplexHeatmap               2.24.1
DBI                          1.2.3
DT                           0.34.0
DelayedArray                 0.34.1
DelayedMatrixStats           1.30.0
Deriv                        4.2.0
DirichletMultinomial         1.50.0
EnsDb.Hsapiens.v86           2.99.0
FNN                          1.1.4.1
Formula                      1.2-5
GenomeInfoDb                 1.44.3
GenomeInfoDbData             1.2.14
GenomicAlignments            1.44.0
GenomicFeatures              1.60.0
GenomicRanges                1.60.0
GetoptLong                   1.0.5
GlobalOptions                0.1.2
HDF5Array                    1.36.0
IRanges                      2.42.0
IRdisplay                    1.1
IRkernel                     1.3.2
JASPAR2020                   0.99.10
KEGGREST                     1.48.1
MatrixGenerics               1.20.0
MatrixModels                 0.5-4
NMF                          0.28
ProtGenerics                 1.40.0
R.methodsS3                  1.8.2
R.oo                         1.27.1
R.utils                      2.12.3-9009
R6                           2.6.1
RANN                         2.6.2
RColorBrewer                 1.1-3
RCurl                        1.98-1.17
ROCR                         1.0-11
RSQLite                      2.4.3
RSpectra                     0.16-2
Rcpp                         1.1.0
RcppAnnoy                    0.0.22
RcppArmadillo                15.0.2-2
RcppCCTZ                     0.2.13
RcppDate                     0.0.6
RcppEigen                    0.3.4.0.2
RcppHNSW                     0.6.0
RcppInt64                    0.0.5
RcppML                       0.3.7
RcppRoll                     0.3.1
RcppSpdlog                   0.0.23
RcppTOML                     0.2.3
Rdpack                       2.6.4
ResidualMatrix               1.18.0
Rhdf5lib                     1.30.0
RhpcBLASctl                  0.23-42
Rhtslib                      3.4.0
Rsamtools                    2.24.1
Rtsne                        0.17
S4Arrays                     1.8.1
S4Vectors                    0.46.0
S7                           0.2.0
ScaledMatrix                 1.16.0
Seurat                       5.3.0
SeuratData                   0.2.2.9002
SeuratDisk                   0.0.0.9021
SeuratObject                 5.2.1
SeuratWrappers               0.4.0
Signac                       1.16.0
SingleCellExperiment         1.30.1
SoupX                        1.6.2
SparseArray                  1.8.1
SparseM                      1.84-2
SummarizedExperiment         1.38.1
TFBSTools                    1.46.0
TFMPvalue                    0.0.9
UCSC.utils                   1.4.0
XML                          3.99-0.19
XVector                      0.48.0
abind                        1.4-8
anndataR                     0.99.5
arrow                        21.0.0.1
askpass                      1.2.1
assertthat                   0.2.1
assorthead                   1.2.0
aws.s3                       0.3.22
aws.signature                0.6.0
backports                    1.5.0
base64enc                    0.1-3
batchelor                    1.24.0
beachmat                     2.24.0
beeswarm                     0.4.0
bit                          4.6.0
bit64                        4.6.0-1
bitops                       1.0-9
blob                         1.2.4
bluster                      1.18.0
brew                         1.0-10
brio                         1.1.5
broom                        1.0.10
bslib                        0.9.0
caTools                      1.18.3
cachem                       1.1.0
callr                        3.7.6
car                          3.1-3
carData                      3.0-5
cellranger                   1.1.0
cellxgene.census             1.16.1
circlize                     0.4.16
classInt                     0.4-11
cli                          3.6.5
clipr                        0.8.0
clue                         0.3-66
coda                         0.19-4.1
colorspace                   2.1-2
commonmark                   2.0.0
corrplot                     0.95
cowplot                      1.2.0
cpp11                        0.5.2
crayon                       1.5.3
credentials                  2.0.3
crosstalk                    1.2.2
curl                         7.0.0
data.table                   1.17.8
deldir                       2.0-4
desc                         1.4.3
devtools                     2.4.6
diffobj                      0.3.6
digest                       0.6.37
distributional               0.5.0
doBy                         4.7.0
doParallel                   1.0.17
dotCall64                    1.2
downlit                      0.4.4
dplyr                        1.1.4
dqrng                        0.4.1
e1071                        1.7-16
edgeR                        4.6.3
ellipsis                     0.3.2
ensembldb                    2.32.0
evaluate                     1.0.5
fansi                        1.0.6
farver                       2.1.2
fastDummies                  1.7.5
fastmap                      1.2.0
fastmatch                    1.1-6
fitdistrplus                 1.2-4
fontawesome                  0.5.3
foreach                      1.5.2
formatR                      1.14
fs                           1.6.6
furrr                        0.3.1
futile.logger                1.4.3
futile.options               1.0.1
future                       1.67.0
future.apply                 1.20.0
gargle                       1.6.0
generics                     0.1.4
gert                         2.1.5
ggalluvial                   0.12.5
ggbeeswarm                   0.7.2
ggdist                       3.3.3
ggforce                      0.5.0
ggnetwork                    0.5.14
ggplot2                      4.0.0
ggpubr                       0.6.2
ggrastr                      1.0.2
ggrepel                      0.9.6
ggridges                     0.5.7
ggsci                        4.0.0
ggsignif                     0.6.4
gh                           1.5.0
gitcreds                     0.1.2
glmGamPoi                    1.20.0
glmpca                       0.2.0
globals                      0.18.0
glue                         1.8.0
goftest                      1.2-3
googledrive                  2.1.2
googlesheets4                1.1.2
gplots                       3.2.0
gridBase                     0.4-7
gridExtra                    2.3
grr                          0.9.5
gtable                       0.3.6
gtools                       3.9.5
h5mread                      1.0.1
harmony                      1.2.4
hdf5r                        1.3.12
here                         1.0.2
hexbin                       1.28.5
highr                        0.11
hms                          1.1.4
htmltools                    0.5.8.1
htmlwidgets                  1.6.4
httpuv                       1.6.16
httr                         1.4.7
httr2                        1.2.1
ica                          1.0-3
ids                          1.0.1
igraph                       2.2.0
ini                          0.3.1
irlba                        2.3.5.1
isoband                      0.2.7
iterators                    1.0.14
jquerylib                    0.1.4
jsonlite                     2.0.0
kBET                         0.99.6
knitr                        1.50
labeling                     0.4.3
lambda.r                     1.2.4
later                        1.4.4
lazyeval                     0.2.2
leidenbase                   0.1.35
lifecycle                    1.0.4
limma                        3.64.3
listenv                      0.9.1
lme4                         1.1-37
lmtest                       0.9-40
locfit                       1.5-9.12
magrittr                     2.0.4
matrixStats                  1.5.0
memoise                      2.0.1
metapod                      1.16.0
microbenchmark               1.5.0
mime                         0.13
miniUI                       0.1.2
minqa                        1.2.8
modelr                       0.1.11
monocle3                     1.4.26
multtest                     2.64.0
nanoarrow                    0.7.0-1
nanotime                     0.3.12
network                      1.19.0
nloptr                       2.2.1
numDeriv                     2016.8-1.1
openssl                      2.3.4
pak                          0.9.0
parallelly                   1.45.1
patchwork                    1.3.2
pbapply                      1.7-4
pbdZMQ                       0.3-14
pbkrtest                     0.5.5
pbmcapply                    1.5.1
pheatmap                     1.0.13
pillar                       1.11.1
pkgbuild                     1.4.8
pkgconfig                    2.0.3
pkgdown                      2.1.3
pkgload                      1.4.1
plotly                       4.11.0
plyr                         1.8.9
png                          0.1-8
polyclip                     1.10-7
polynom                      1.4-1
praise                       1.0.0
presto                       1.0.0
prettyunits                  1.2.0
processx                     3.8.6
profvis                      0.4.0
progress                     1.2.3
progressr                    0.17.0
promises                     1.3.3
proxy                        0.4-27
ps                           1.9.1
pscl                         1.5.9
purrr                        1.1.0
pwalign                      1.4.0
quadprog                     1.5-8
quantreg                     6.1
ragg                         1.5.0
rappdirs                     0.3.3
rbibutils                    2.3
rcmdcheck                    1.4.0
readr                        2.1.5
reformulas                   0.4.1
registry                     0.5-1
rematch                      2.0.0
rematch2                     2.1.2
remotes                      2.5.0
repr                         1.1.7
reshape2                     1.4.4
restfulr                     0.0.16
reticulate                   1.43.0
rhdf5                        2.52.1
rhdf5filters                 1.20.0
rjson                        0.2.23
rlang                        1.1.6
rmarkdown                    2.30
rngtools                     1.5.2
roxygen2                     7.3.3
rprojroot                    2.1.1
rsample                      1.3.1
rstatix                      0.7.3
rstudioapi                   0.17.1
rsvd                         1.0.5
rtracklayer                  1.68.0
rversions                    3.0.0
s2                           1.1.9
sass                         0.4.10
scDblFinder                  1.23.4
scales                       1.4.0
scater                       1.36.0
scattermore                  1.2
scran                        1.36.0
scry                         1.20.0
sctransform                  0.4.2
scuttle                      1.18.0
seqLogo                      1.74.0
sessioninfo                  1.2.3
sf                           1.0-21
shape                        1.4.6.1
shiny                        1.11.1
shinyBS                      0.61.1
shinydashboard               0.7.3
shinyjs                      2.1.0
slam                         0.1-55
slider                       0.3.2
sna                          2.8
snow                         0.4-4
sourcetools                  0.1.7-1
sp                           2.2-0
spData                       2.3.4
spam                         2.11-1
sparseMatrixStats            1.20.0
spatstat.data                3.1-9
spatstat.explore             3.5-3
spatstat.geom                3.6-0
spatstat.random              3.4-2
spatstat.sparse              3.1-0
spatstat.univar              3.1-4
spatstat.utils               3.2-0
spdep                        1.4-1
spdl                         0.0.5
speedglm                     0.3-4
statmod                      1.5.1
statnet.common               4.12.0
stringi                      1.8.7
stringr                      1.5.2
svglite                      2.2.1
sys                          3.4.3
systemfonts                  1.3.1
tensor                       1.5.1
testthat                     3.2.3
textshaping                  1.0.4
tibble                       3.3.0
tidyr                        1.3.1
tidyselect                   1.2.1
tiledb                       0.33.1
tiledbsoma                   2.1.0
tinytex                      0.57
tweenr                       2.0.3
tzdb                         0.5.0
units                        1.0-0
urlchecker                   1.0.1
usethis                      3.2.1
utf8                         1.2.6
uuid                         1.2-1
uwot                         0.2.3
vctrs                        0.6.5
vipor                        0.4.7
viridis                      0.6.5
viridisLite                  0.4.2
vroom                        1.6.6
waldo                        0.6.2
warp                         0.2.1
whisker                      0.4.1
withr                        3.0.2
wk                           0.9.4
xfun                         0.53
xgboost                      1.7.11.1
xml2                         1.4.0
xopen                        1.0.1
xtable                       1.8-4
yaml                         2.3.10
zip                          2.3.3
zoo                          1.8-14
KernSmooth                   2.23-26
MASS                         7.3-65
Matrix                       1.7-4
base                         4.5.1
boot                         1.3-32
class                        7.3-23
cluster                      2.1.8.1
codetools                    0.2-19
compiler                     4.5.1
datasets                     4.5.1
foreign                      0.8-90
grDevices                    4.5.1
graphics                     4.5.1
grid                         4.5.1
lattice                      0.22-5
methods                      4.5.1
mgcv                         1.9-1
nlme                         3.1-168
nnet                         7.3-20
parallel                     4.5.1
rpart                        4.1.24
spatial                      7.3-15
splines                      4.5.1
stats                        4.5.1
stats4                       4.5.1
survival                     3.8-3
tcltk                        4.5.1
tools                        4.5.1
utils                        4.5.1
```
</details>

<!--VERSIONS_END-->
