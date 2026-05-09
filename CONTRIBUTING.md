# Git Branching Strategy & Contribution Guidelines

To ensure a stable and clean development history, we follow a feature-branch-based workflow.

## Branching Strategy

- **`main`**: The primary stable branch. All code in `main` should be fully functional and tested.
- **`feature/<phase-or-feature>`**: Use these branches for developing new phases, features, or significant refinements (e.g., `feature/phase-6-polish`).
- **`bugfix/<issue-description>`**: Use these for specific bug fixes found during testing.
- **`hotfix/<description>`**: Emergency fixes that need to be merged directly into `main`.

## Typical Workflow

1.  **Pull latest changes**: Always start by ensuring your local `main` is up to date.
    ```bash
    git checkout main
    git pull origin main
    ```
2.  **Create a feature branch**:
    ```bash
    git checkout -b feature/phase-6-polish
    ```
3.  **Develop and Commit**: Follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g., `feat:`, `fix:`, `docs:`, `refactor:`).
    ```bash
    git commit -m "feat: implement unit tests for transformer"
    ```
4.  **Push and Create Pull Request**: Push the branch and create a PR using the GitHub CLI.
    ```bash
    git push -u origin feature/phase-7-stateful
    gh pr create --title "feat: implement phase 7" --body "Detailed description of changes"
    ```
5.  **Merge via PR**: Changes must be merged into `main` via the Pull Request interface (either on GitHub or via `gh pr merge`) after verification.

## Commit Message Standards

- `feat`: A new feature or phase implementation.
- `fix`: A bug fix.
- `docs`: Documentation changes only.
- `refactor`: A code change that neither fixes a bug nor adds a feature.
- `test`: Adding missing tests or correcting existing tests.
- `chore`: Changes to the build process or auxiliary tools.
