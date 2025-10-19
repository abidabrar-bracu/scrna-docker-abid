# --- Python + CUDA base (includes conda, PyTorch 2.4.1, CUDA 12.1) ---
FROM pytorch/pytorch:2.4.1-cuda12.1-cudnn9-runtime

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

# --- Create dev user to match devcontainer.json ---
RUN useradd -m -s /bin/bash vscode && \
    chown -R vscode:vscode /opt/conda
WORKDIR /workspace

# --- Python packages (GPU-ready) ---
# torch is already present in the base image (2.4.1 + cu121)
RUN pip install --no-cache-dir \
    jupyterlab notebook ipykernel \
    pandas numpy scipy scikit-learn scikit-image statsmodels seaborn matplotlib anndata2ri \
    'scanpy[leiden]' 'squidpy[interactive]' \
    "spatialdata[extra]" spatialdata-plot spatialdata-io\
    igraph \
    leidenalg \
    bbknn \
    scikit-misc \
    rpy2 \
    scib scib-metrics \
    celltypist scarches harmonypy \
    scvelo \
    decoupler pertpy liana spatialde tangram-sc \
    "scvi-tools[cuda]"

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

USER vscode

# --- Convenience: expose Jupyter default port ---
EXPOSE 8888

# --- Final sanity: print versions on first run ---
CMD ["/bin/bash"]
