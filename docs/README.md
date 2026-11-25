# Documentation Info

Documentation is built using [Documenter](https://github.com/JuliaDocs/Documenter.jl).

The [Documentation workflow](../.github/workflows/docs.yml) builds the docs on pull requests and publishes successful builds from `main` to GitHub Pages, retaining the existing `/build/` URLs. It can also be run manually from the Actions tab. In the repository's Settings > Pages, set the publishing source to **GitHub Actions**.

Workflow for updating documentation:
- Modify `make.jl` or files in the `src` folder.
- Build the docs locally from the root of DarOne.jl:

  ```bash
  julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
  julia --project=docs docs/make.jl
  ```

- Check the generated pages in `docs/build`.
- Open a pull request with the source changes. The generated `docs/build` folder should remain untracked.
