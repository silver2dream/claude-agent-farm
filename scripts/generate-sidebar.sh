#!/bin/bash
# Generate Docsify _sidebar.md from project folder structure
# Run this periodically or after discussions to update the dashboard navigation

PROJECTS_DIR="${1:-/data/game-studio-projects}"

cat > "$PROJECTS_DIR/_sidebar.md" << 'HEADER'
* **🪐 Game Studio Dashboard**
HEADER

# Scan each project
for project_dir in "$PROJECTS_DIR"/*/; do
  [ -d "$project_dir" ] || continue
  project=$(basename "$project_dir")
  echo "" >> "$PROJECTS_DIR/_sidebar.md"
  echo "* **📁 $project**" >> "$PROJECTS_DIR/_sidebar.md"

  # Scan markdown files recursively, sorted by path
  find "$project_dir" -name "*.md" -type f | sort | while read -r md_file; do
    rel_path="${md_file#$PROJECTS_DIR/}"
    filename=$(basename "$md_file" .md)
    # Indent based on depth
    depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
    indent=""
    for ((i=1; i<depth; i++)); do indent="  $indent"; done
    echo "${indent}  * [$filename](/$rel_path)" >> "$PROJECTS_DIR/_sidebar.md"
  done
done

echo "✅ Sidebar generated at $PROJECTS_DIR/_sidebar.md"
