library(httr2)
library(dotenv)
library(curl)
library(jsonlite)
library(fs) # for better path handling

# Load credentials
dotenv::load_dot_env()
pinata_key    <- Sys.getenv("PINATA_API_KEY")
pinata_secret <- Sys.getenv("PINATA_API_SECRET")
ud_api_key    <- Sys.getenv("UD_API_KEY")
ud_domain     <- "fireinthecave.x"

# Config
project_path <- path.expand("~/Sync/syncthing_quarto/fire-in-the-cave")
docs_path    <- file.path(project_path, "docs")
private_dirs <- c("fragments", "books", "chapters", "data")

# ── Step 0: Sovereign Guard ──────────────────────────────────────────────────
message("Checking for private leaks...")
all_rendered_files <- list.files(docs_path, recursive = TRUE)

# Scan rendered docs for any trace of private folder names in the paths
leaks <- Filter(function(f) any(sapply(private_dirs, function(d) grepl(paste0("^", d, "/"), f))), all_rendered_files)

if (length(leaks) > 0) {
  message("CRITICAL ERROR: Private data detected in output directory!")
  message(paste0("  Leak detected in: ", head(leaks, 3), collapse = "\n"))
  stop("Deployment aborted to protect the Cave. Check your _quarto.yml render settings.")
}
message("  Clear. No private mass detected in public build.")

# ── Step 1: Render ────────────────────────────────────────────────────────────
message("Rendering Quarto site (Public Profile)...")
# We explicitly do NOT use --profile internal here
render_result <- system("quarto render") 
if (render_result != 0) stop("Quarto render failed. Aborting.")

# ── Step 2: Upload docs/ folder to Pinata ───────────────────────────────────
message("Uploading to Pinata...")
all_files <- list.files(docs_path, recursive = TRUE, full.names = TRUE)
rel_paths  <- substring(all_files, nchar(docs_path) + 2)

req_pinata <- request("https://api.pinata.cloud/pinning/pinFileToIPFS") %>%
  req_headers(pinata_api_key = pinata_key, pinata_secret_api_key = pinata_secret)

body_list <- list()
body_list[["pinataMetadata"]] <- jsonlite::toJSON(list(name = "fireinthecave-site"), auto_unbox = TRUE)
body_list[["pinataOptions"]]  <- jsonlite::toJSON(list(cidVersion = 1), auto_unbox = TRUE)

for (i in seq_along(all_files)) {
  body_list[[paste0("file", i)]] <- curl::form_file(all_files[i], type = NULL, name = rel_paths[i])
}

pin_response <- req_pinata %>%
  req_body_multipart(!!!body_list) %>%
  req_perform()

cid <- resp_body_json(pin_response)$IpfsHash
message(paste0("  Upload complete. CID: ", cid))

# ── Step 3: Update Unstoppable (Skipped if UD is locked) ────────────────────
# [Keep your existing Step 3 logic here]

# ── Step 4: Git Push ────────────────────────────────────────────────────────
# [Keep your existing Step 4 logic here]

message("Done. The Cave remains secure.")