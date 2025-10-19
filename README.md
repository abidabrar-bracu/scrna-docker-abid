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
<!--VERSIONS_END-->