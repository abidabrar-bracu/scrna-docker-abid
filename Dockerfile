# --- Python + CUDA base (includes conda, PyTorch 2.9.0, CUDA 12.8) ---
FROM pytorch/pytorch:2.9.0-cuda12.8-cudnn9-devel

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Berlin \
    PIP_NO_CACHE_DIR=1 \
    PAK_PKG_SYSREQS=true

# --- System deps  ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libharfbuzz-dev libfribidi-dev libfontconfig1-dev libxt-dev && \
    apt-get install -y --no-install-recommends tzdata && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get install -y --no-install-recommends \
        software-properties-common dirmngr gnupg ca-certificates wget curl git \
        build-essential gfortran cmake pkg-config \
        libssl-dev libcurl4-openssl-dev libxml2-dev \
        libhdf5-dev zlib1g-dev liblzma-dev libbz2-dev \
        libpng-dev libjpeg-dev libtiff5-dev libfreetype6-dev \
        liblapack-dev libblas-dev libopenblas-dev \
        libzmq3-dev libgit2-dev libglpk-dev \
    && rm -rf /var/lib/apt/lists/*

# --- R 4.4 from CRAN (Ubuntu Jammy) ---
RUN bash -lc 'set -e; \
    . /etc/os-release; \
    echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/cran.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${VERSION_CODENAME}-cran40/" | tee /etc/apt/sources.list.d/cran-r.list; \
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/cran.gpg; \
    apt-get update && apt-get install -y --no-install-recommends r-base r-base-dev && \
    rm -rf /var/lib/apt/lists/*'

# ------------------------------------------------------------
#  Install latest code-server
# ------------------------------------------------------------
RUN CODE_URL=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest \
        | grep browser_download_url \
        | grep linux-amd64.tar.gz \
        | cut -d '"' -f 4) && \
        curl -fsSL "$CODE_URL" | tar -xz -C /usr/local --strip-components=1

# ------------------------------------------------------------
# Create workspace and VS Code directories
# ------------------------------------------------------------
RUN mkdir -p /workspace /config/.vscode/extensions
RUN code-server --install-extension ms-python.python
RUN code-server --install-extension ms-toolsai.jupyter


# --- Create dev user to match devcontainer.json ---
RUN useradd -m -s /bin/bash vscode && \
    chown -R vscode:vscode /opt/conda
WORKDIR /workspace

# --- Python packages (GPU-ready) ---
# --- Base scientific stack ---
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
        numpy==2.3.3 scipy==1.15.3 scikit-learn scikit-image==0.25.2 \
        statsmodels seaborn matplotlib==3.10.7
# --- scAnalysis core packages ---
# pinning numpy/scipy/skimage for compatibility
RUN pip install --no-cache-dir \
    numpy==2.3.3 scipy==1.15.3 scikit-learn scikit-image==0.25.2 \
    rpy2 jupyterlab notebook ipykernel \
    kiwisolver==1.4.9 vispy napari==0.6.6 \
    anndata2ri \
    'scanpy[dask,leiden]==1.11.5' \
    "dask[distributed,diagnostics]" sklearn-ann annoy \
    igraph umap-learn leidenalg bbknn scikit-misc \
    "jax[cuda12]==0.8.0" jaxlib==0.8.0 \
    "scvi-tools[cuda,autotune,parallel,interpretability,dataloaders]==1.4.0.post1" \
    scib scib-metrics scarches \
    "ray[data,train,tune,serve]" \
    'squidpy[interactive]==1.6.5' \
    "spatialdata[extra]==0.5.0" \
    celltypist harmonypy \
    scvelo \
    decoupler pertpy liana spatialde tangram-sc \
    cellxgene-census \
    gh

# WARNING: the latest version of AnnData does not have anndata.read, so scarches import can fail.
# Workaround at runtime:
#   import anndata as ad; ad.read = ad.read_h5ad

# --- R packages (CRAN/Bioc/GitHub/pak) ---
# install pak for package management and other package managers
RUN R -q -e "install.packages('pak', repos = sprintf('https://r-lib.github.io/p/pak/stable/%s/%s/%s', .Platform\$pkgType, R.Version()\$os, R.Version()\$arch))"
RUN echo "options(repos=c(CRAN='https://packagemanager.posit.co/cran/__linux__/jammy/latest'), pkgType='binary')" >> /etc/R/Rprofile.site
RUN R -q -e "pak::pkg_install(c('remotes','BiocManager','devtools'))"

# pre-seurat dependencies
RUN R -q -e "pak::pkg_install(c('rhdf5', 'SingleCellExperiment', 'scry', 'multtest', 'scater'))" 
RUN R -q -e "pak::pkg_install(c('SoupX', 'plger/scDblFinder'))"

## for some reason, pkgType=binary causes issues with BPCells installation, and cannot be installed via pak
RUN sed -i '/pkgType/d' /etc/R/Rprofile.site
RUN R -q -e "remotes::install_github('bnprks/BPCells/r')"
RUN R -q -e "remotes::install_github('HenrikBengtsson/R.utils')"
# restore binary preference for speed
RUN echo "options(repos=c(CRAN='https://packagemanager.posit.co/cran/__linux__/jammy/latest'), pkgType='binary')" >> /etc/R/Rprofile.site

# Seurat and related packages
RUN R -q -e "pak::pkg_install(c('Seurat', 'SeuratObject', 'satijalab/seurat-wrappers', 'mojaveazure/seurat-disk', 'satijalab/azimuth', 'satijalab/seurat-data', 'stuart-lab/signac'))"
# ensure latest SeuratObject with fix for xenium data
RUN R -q -e "devtools::install_github('satijalab/seurat-object', ref = 'fix/update-seurat-object')"
# anndataR and harmony
RUN R -q -e "pak::pkg_install(c('scverse/anndataR', 'harmony'))"


# Monocle 3 dependencies
RUN R -q -e "pak::pkg_install(c('BiocGenerics', 'DelayedArray', 'DelayedMatrixStats', 'limma', 'lme4', 'S4Vectors', 'SingleCellExperiment', 'SummarizedExperiment', 'batchelor', 'HDF5Array', 'ggrastr'))"
# Monocle 3 ('cole-trapnell-lab/monocle3')
RUN R -q -e "pak::pkg_install('cole-trapnell-lab/monocle3')"

# CellChat Dependencies
RUN R -q -e "pak::pkg_install(c('NMF', 'circlize', 'ComplexHeatmap'))"
# CellChat
RUN R -q -e "pak::pkg_install('jinworks/CellChat')"

# kBET
RUN R -q -e "pak::pkg_install('theislab/kBET')"

# finally CellXGene Census R package
RUN sed -i '/pkgType/d' /etc/R/Rprofile.site
RUN R -q -e "install.packages('tiledb', repos = c('https://tiledb-inc.r-universe.dev', 'https://cloud.r-project.org'))"
RUN R -q -e "install.packages('cellxgene.census', repos=c('https://chanzuckerberg.r-universe.dev', 'https://cloud.r-project.org'))"


# --- Fix plotting fonts in jupyter lab ---
# install font dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev libxt-dev libfontconfig1-dev fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*

# R user profile (fonts + ggplot theme)
RUN mkdir -p /home/vscode && \
    printf '%s\n' \
'if (requireNamespace("Cairo", quietly = TRUE)) {' \
'  try({' \
'    Cairo::CairoFonts(' \
'      regular    = "DejaVu Sans:style=Book",' \
'      bold       = "DejaVu Sans:style=Bold",' \
'      italic     = "DejaVu Sans:style=Oblique",' \
'      bolditalic = "DejaVu Sans:style=Bold Oblique"' \
'    )' \
'    options(repr.plot.use.cairo = TRUE)' \
'    setHook(packageEvent("ggplot2","onLoad"), function(...) ggplot2::theme_set(ggplot2::theme_bw(base_size=11, base_family="DejaVu Sans")) )' \
'  }, silent = TRUE)' \
'}' \
> /home/vscode/.Rprofile && chown vscode:vscode /home/vscode/.Rprofile


# --- Register R kernel for Jupyter (also run in postCreate to be sure) ---
RUN R -q -e "pak::pkg_install('IRkernel')"
RUN R -q -e "IRkernel::installspec(user=FALSE)" 
RUN python -m ipykernel install --name scanalysis --display-name "scAnalysis (base)" --prefix=/usr/local

# --- Version report generation (Python + R) ---
RUN mkdir -p /workspace/docs && chmod 777 /workspace/docs

# Python version summary (installed package names)
RUN python - <<'PY'
import importlib.metadata as metadata, json, os

out = {dist.metadata["Name"]: dist.version for dist in metadata.distributions()}
os.makedirs("/workspace/docs", exist_ok=True)
with open("/workspace/docs/python_versions.json", "w") as f:
    json.dump(out, f, indent=2, sort_keys=True)
print(f"Wrote {len(out)} Python packages → /workspace/docs/python_versions.json")
PY

# R version summary
RUN R -q -e "dir.create('/workspace/docs', showWarnings=FALSE); \
  write.table(as.data.frame(installed.packages()[,c('Package','Version')]), \
  file='/workspace/docs/R_versions.tsv', sep='\t', row.names=FALSE, quote=FALSE)"

# --- Cleanup ---
RUN apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -rf /usr/local/lib/R/site-library/*/help \
    /usr/local/lib/R/site-library/*/doc \
    /usr/local/lib/R/site-library/*/html \
    /usr/local/lib/R/site-library/*/tests \
    /usr/local/lib/R/site-library/*/demo \
    /usr/local/lib/R/site-library/*/libs/*.o \
    /tmp/* /var/tmp/*

RUN rm -rf /usr/share/man /usr/share/doc /usr/share/locale


# --- Workspace setup ---
RUN mkdir -p /workspace && chown -R vscode:vscode /workspace
USER vscode

# --- Convenience: expose Jupyter default port ---
EXPOSE 8888

# --- Final sanity: print versions on first run ---
CMD ["/bin/bash"]
