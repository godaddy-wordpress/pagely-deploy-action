# Pagely Deploy Action
GitHub action for deploying to [Pagely](https://pagely.com/) Apps

## Inputs

| Name                        | Requirement | Description                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|-----------------------------|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `PAGELY_INTEGRATION_SECRET` | _required_  | Authentication token. Create a CI Integration at [Atomic](https://atomic.pagely.com/account/integrations) to get this.                                                                                                                                                                                                                                                                                                                         |
| `PAGELY_INTEGRATION_ID`     | _required_  | Unique ID for the integration found in Atomic.                                                                                                                                                                                                                                                                                                                                                                                                 |
| `PAGELY_APP_ID`             | _required_  | Numeric ID of the app you want to deploy to, available in Atomic.                                                                                                                                                                                                                                                                                                                                                                              |
| `PAGELY_DEPLOY_DEST`        | _required_  | Set the subdirectory to deploy to within the app. `/httpdocs` would be the web root of your app. Examples: `/httpdocs`, `/httpdocs/wp-content/plugins/my-plugin`                                                                                                                                                                                                                                                                               |
| `PAGELY_WORKING_DIR`        | _optional_  | The directory that you want deployed relative to the repository root. If you want to deploy your entire repository contents, then you can leave this blank to use the default (`${{ github.workspace }}`), otherwise you should specify the directory prefixed with `${{ github.workspace }}`. For example, if you have built artifacts you wish to deploy inside a directory called `build`, you can specify `${{ github.workspace }}/build`. |

## Example usage

The GitHub workflow below shows an example that pushes the contents of the repository to the `/httpdocs/wp-content/plugins/my-plugin` directory of the Pagely app.

The workflow is triggered on every push to the `main` branch of the repository.

```yaml
---
on:
  push:
    branches:
      - main
jobs:
  deploy:
    name: Deploy to Pagely App
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3
        
      - name: Run deploy
        uses: godaddy-wordpress/pagely-deploy-action@v1
        with:
          PAGELY_DEPLOY_DEST: "/httpdocs/wp-content/plugins/my-plugin"
          PAGELY_INTEGRATION_SECRET: ${{ secrets.PAGELY_INTEGRATION_SECRET }}
          PAGELY_INTEGRATION_ID: ${{ secrets.PAGELY_INTEGRATION_ID }}
          PAGELY_APP_ID: ${{ secrets.PAGELY_APP_ID }}
          PAGELY_WORKING_DIR: "${{ github.workspace }}" # use the files starting at the repository root
```
