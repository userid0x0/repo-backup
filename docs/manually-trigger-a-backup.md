# Manually trigger a backup

Sometimes, it's necessary to manually trigger backup actions.

This can be useful when other programs are used to consistently schedule tasks or to verify that environment variables are properly configured.

## Usage

You can perform a backup directly with a parameterless command.

```shell
docker run \
  --rm \
  --name repo_backup \
  --mount type=volume,source=rclone-data,target=/config/ \
  -e ... \
  userid0x0/repo-backup:latest backup
```

You also need to mount the rclone config file and set the environment variables.

The only difference is that the environment variable `CRON` does not work because it does not start the CRON program, but exits the container after the backup is done.

## NOTE

Manually triggering a backup only verifies that the environment variables are configured correctly, not that CRON is working properly.

