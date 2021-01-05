[![cicd](https://github.com/jmpa-oss/linter/workflows/cicd/badge.svg)](https://github.com/jmpa-oss/linter/actions?query=workflow%3Acicd)
[![update](https://github.com/jmpa-oss/linter/workflows/update/badge.svg)](https://github.com/jmpa-oss/linter/actions?query=workflow%3Aupdate)

# linter

```diff
+ A GitHub Action for linting (eg. Bash, Go, CloudFormation, Dockerfiles, etc)
```

* To learn about creating a custom GitHub Action like this, see [this doc](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/creating-a-docker-container-action).

## usage

basic usage:

```yaml
- name: Lint
  uses: jmpa-oss/linter@v0.0.1
```

This will fail the build if there are any linting issues.

To ignore these linting issues, use:

```yaml
- name: Lint
  uses: jmpa-oss/linter@v0.0.1
  continue-on-error: true
```

## pushing new tag?

```bash
git tag -m "<message>" <version>
git push --tags
```
