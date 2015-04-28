config <- list(
    # Maximum number of genes to keepp
    max_ngenes_tokeep = 500,
    # Maximum fraction of genes to keep
    max_fgenes_tokeep = 1,
    # Number of bars in the PAEA bar plot
    num_paea_bars = 15,
    # Number of digits to keep for displaying the expression data
    digits = 3,
    # Path of the meta data file of disease signatures
    dz_meta = 'data/meta.txt',
    # Port for the flask server
    port = 5050,
    # URL for the `paea` API
    api_url = 'http://127.0.0.1:5050/api'
)