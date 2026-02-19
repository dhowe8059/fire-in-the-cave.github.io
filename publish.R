library(httr2)
library(dotenv)
library(curl)
library(httr)
library(jsonlite)

# Load credentials
dotenv::load_dot_env()
pinata_key    <- Sys.getenv("PINATA_API_KEY")
pinata_secret <- Sys.getenv("PINATA_API_SECRET")
ud_api_key    <- Sys.getenv("UD_API_KEY")
ud_domain     <- "fireinthecave.x"

# Commit message as argument, default if none provided
args <- commandArgs(trailingOnly = TRUE)
commit_msg <- ifelse(length(args) > 0, args[1], "site update")

project_path <- "~/Sync/syncthing_quarto/fire-in-the-cave"
docs_path    <- path.expand(file.path(project_path, "docs"))

# ── Step 1: Render ────────────────────────────────────────────────────────────
message("Rendering Quarto site...")
render_result <- system("quarto render")
if (render_result != 0) stop("Quarto render failed. Aborting.")

# ── Step 2: Upload docs/ folder to Pinata ───────────────────────────────────
message("Uploading to Pinata...")
all_files <- list.files(docs_path, recursive = TRUE, full.names = TRUE)
rel_paths  <- substring(all_files, nchar(docs_path) + 2)

if (length(all_files) == 0) stop("docs/ folder is empty. Aborting.")
message(paste0("  Found ", length(all_files), " files to upload..."))

# Build curl command — all files prefixed with "site/" as common root
file_args <- paste(sapply(seq_along(all_files), function(i) {
  paste0('--form "file=@', all_files[i], 
         ';filename=site/', rel_paths[i], '"')
}), collapse = " ")

cmd <- paste0(
  'curl -s -X POST "https://api.pinata.cloud/pinning/pinFileToIPFS" ',
  '-H "pinata_api_key: ', pinata_key, '" ',
  '-H "pinata_secret_api_key: ', pinata_secret, '" ',
  file_args, ' ',
  '--form "pinataMetadata={\\"name\\":\\"fireinthecave-site\\"}" ',
  '--form "pinataOptions={\\"wrapWithDirectory\\":false}"'
)

response_json <- system(cmd, intern = TRUE)
result <- jsonlite::fromJSON(paste(response_json, collapse = ""))

if (is.null(result$IpfsHash)) {
  stop(paste0("Pinata upload failed: ", paste(response_json, collapse = "")))
}

cid <- result$IpfsHash
message(paste0("  Upload complete."))
message(paste0("  CID: ", cid))
message(paste0("  Preview: https://gateway.pinata.cloud/ipfs/", cid))


# ── Step 3: Update Unstoppable Domains ───────────────────────────────────────
message("Updating Unstoppable Domains...")

if (nchar(ud_api_key) == 0) {
  message("  UD_API_KEY not set — skipping. Paste CID manually:")
  message(paste0("  CID: ", cid))
} else {
  ud_url <- paste0("https://api.unstoppabledomains.com/domains/", ud_domain)
  
  ud_response <- request(ud_url) |>
    req_headers(
      Authorization  = paste("Bearer", ud_api_key),
      `Content-Type` = "application/json"
    ) |>
    req_body_json(list(
      records = list(`dweb.ipfs.hash` = cid)
    )) |>
    req_method("PATCH") |>
    req_error(is_error = \(resp) FALSE) |>
    req_perform()
  
  message(paste0("  UD status: ", resp_status(ud_response)))
  message(resp_body_string(ud_response))
} 

# ── Step 4: Git push to GitHub Pages ─────────────────────────────────────────
message("Pushing to GitHub...")
system(paste0("cd ", path.expand(project_path), " && git add ."))
system(paste0("cd ", path.expand(project_path), 
              ' && git commit -m "', commit_msg, '"'))
system(paste0("cd ", path.expand(project_path), " && git push origin main"))

# ── Done ──────────────────────────────────────────────────────────────────────
message("─────────────────────────────────────")
message("Done.")
message(paste0("GitHub Pages: https://fireinthecave.com"))
message(paste0("IPFS:         https://gateway.pinata.cloud/ipfs/", cid))
message(paste0("CID:          ", cid))