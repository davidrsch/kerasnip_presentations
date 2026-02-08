# kerasnip presentations

[![Render and Publish](https://github.com/davidrsch/kerasnip_presentations/actions/workflows/publish.yml/badge.svg)](https://github.com/davidrsch/kerasnip_presentations/actions/workflows/publish.yml)

This repository hosts slides and presentation materials for the [`kerasnip`](https://github.com/davidrsch/kerasnip) R package — a bridge between Keras and tidymodels.

🌐 **Live site**: [davidrsch.github.io/kerasnip_presentations](https://davidrsch.github.io/kerasnip_presentations/)

## Available Presentations

| Presentation | Event | Date |
|--------------|-------|------|
| [A Bridge Between 'keras' and 'tidymodels'](https://davidrsch.github.io/kerasnip_presentations/presentations/madrid-2-2026/) | Madrid R Group | February 2026 |

## Features

- **Bilingual**: Presentations available in English and Spanish
- **RevealJS slides**: Interactive, web-based presentations
- **Reproducible**: Each presentation has its own `renv` environment
- **Automated publishing**: GitHub Actions renders and deploys to GitHub Pages

## Project Structure

```
kerasnip_presentations/
├── presentations/
│   └── madrid-2-2026/       # First presentation
│       ├── index.qmd        # Presentation source
│       ├── renv.lock        # R dependencies
│       └── ...
├── _quarto.yml              # Main Quarto config
├── index.qmd                # Landing page
└── .github/workflows/       # CI/CD pipeline
```

## Local Development

### Prerequisites

- [Quarto](https://quarto.org/)
- R with [`renv`](https://rstudio.github.io/renv/)

### Rendering the main site

```bash
quarto render --profile english
# or
quarto render --profile spanish
```

### Rendering a specific presentation

```bash
cd presentations/madrid-2-2026
renv::restore()  # in R
quarto render --profile english
```

## License

Content © David Díaz Rodríguez. Code examples from `kerasnip` are under the same license as the package.
