# Design

The working copy stays a local JSON file. `KithCloudStore` writes the same
payload to one private CloudKit record named `current`. `KithDocument.newer`
picks the later `savedAt`. Missing iCloud is not an error.
