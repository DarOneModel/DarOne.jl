# Documentation Info

Documentation is built using [Documenter](https://github.com/JuliaDocs/Documenter.jl).

Documentation is built automatically on pull requests and published to GitHub Pages when changes are merged into main.
Workflow for updating documentation:
- Modify `make.jl` or files in the `src` folder.
- Build the docs locally from the root of DarOne.jl:

  ```bash
  julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
  julia --project=docs docs/make.jl
  ```

- Check the generated pages in `docs/build`.
- Open a pull request with the source changes. The generated `docs/build` folder should remain untracked.
