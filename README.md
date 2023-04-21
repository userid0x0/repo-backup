# Repo-Backup

[![Docker Image](https://img.shields.io/badge/Docker%20Image-available-success&style=flat)](https://hub.docker.com/r/userid0x0/repo-backup/)
[![Build](https://img.shields.io/github/actions/workflow/status/userid0x0/repo-backup/docker-image.yml?branch=master&label=build&logo=github&style=flat)](https://github.com/userid0x0/repo-backup/actions)
 [![GitHub](https://img.shields.io/github/license/userid0x0/repo-backup?label=License&logo=github&style=flat)](https://github.com/userid0x0/repo-backup/blob/master/LICENSE)

Backup Subversion (future git) Repositories using rclone.

- [Docker Hub](https://hub.docker.com/r/userid0x0/repo-backup)
- [GitHub](https://github.com/userid0x0/repo-backup)

The container is heavily inspired by [ttionya/vaultwarden-backup](https://github.com/ttionya/vaultwarden-backup) and offers the same usage.
Might be used in conjunction with [userid0x0/svn-docker](https://github.com/userid0x0/svn-docker).

## Feature

This tool supports backing up exports of the following repository types

- [x] Subversion/SVN
- [ ] Git

And the following ways of notifying backup results are supported.

- Ping (only send on success)
- Mail (SMTP based, send on success and on failure)

## Usage

### Configure Rclone (⚠️ MUST READ ⚠️)

> **For backup, you need to configure Rclone first, otherwise the backup tool will not work.**

We upload the backup files to the storage system by [Rclone](https://rclone.org/).

Visit [GitHub](https://github.com/rclone/rclone) for more storage system tutorials. Different systems get tokens differently.

#### Configure and Check

You can get the token by the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-data,target=/config/ \
  userid0x0/repo-backup:latest \
  rclone config
```

**We recommend setting the remote name to `RepoBackup`, otherwise you need to specify the environment variable `RCLONE_REMOTE_NAME` as the remote name you set.**

After setting, check the configuration content by the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-data,target=/config/ \
  userid0x0/repo-backup:latest \
  rclone config show

# Microsoft Onedrive Example
# [RepoBackup]
# type = onedrive
# token = {"access_token":"access token","token_type":"token type","refresh_token":"refresh token","expiry":"expiry time"}
# drive_id = driveid
# drive_type = personal
```

### Backup

#### Use Docker Compose (Recommended)

Download `docker-compose.yml` to you machine, edit environment variables and start it.

You need to go to the directory where the `docker-compose.yml` file is saved.

```shell
# Start
docker-compose up -d

# Stop
docker-compose stop

# Restart
docker-compose restart

# Remove
docker-compose down
```

#### Automatic Backups

Start the backup container with default settings. (automatic backup at 5 minute every hour)

```shell
docker run -d \
  --restart=always \
  --name repo_backup \
  --mount type=volume,source=rclone-data,target=/config/ \
  userid0x0/repo-backup:latest
```

## Repository Configuration
### Subversion/SVN
To configure Subversion repositories to backup, use the environment variables

- `SVN_REPO_NAME_N` name of the repository, name will be part of the backup file `svn_<SVN_REPO_NAME_N>.<>.<zip|7z>`
- `SVN_REPO_URL_N` url of the repository e.g. `http://svn.local/svn/repo/trunk`
- [optional]`SVN_REPO_USERNAME_N` SVN Credentials Username
- [optional]`SVN_REPO_PASSWORD_N` SVN Credentials Password in plaintext

, where:

- `N` is a serial number, starting from 0 and increasing consecutively for each additional destination
- `SVN_REPO_NAME_N` and `SVN_REPO_URL_N` cannot be empty

Note that if the serial number is not consecutive or the value is empty, the script will break parsing the environment variables for Subversion repositories.

#### Example
Backup repository `docs/trunk` from server `svn.local` using `http://`.

```yml
...
environment:
  # no username/password
  SVN_REPO_NAME_0: documentation-trunk
  SVN_REPO_URL_0: http://svn.local/svn/docs/trunk
  # with username/password
  SVN_REPO_NAME_0: documentation-trunk
  SVN_REPO_URL_0: http://svn.local/svn/docs/trunk
  SVN_REPO_USERNAME_0: <username>
  SVN_REPO_PASSWORD_0: <password>
...
```

## Environment Variables

> **Note:** All environment variables have default values, you can use the docker image without setting any environment variables.

#### RCLONE_REMOTE_NAME

The name of the Rclone remote, which needs to be consistent with the remote name in the rclone config.

You can view the current remote name with the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-data,target=/config/ \
  userid0x0/repo-backup:latest \
  rclone config show

# [RepoBackup] <- this
# ...
```

Default: `RepoBackup`

#### RCLONE_REMOTE_DIR

The folder where backup files are stored in the storage system.

Default: `/RepoBackup/`

#### RCLONE_GLOBAL_FLAG

Rclone global flags, see [flags](https://rclone.org/flags/).

**Do not add flags that will change the output, such as `-P`, which will affect the deletion of outdated backup files.**

Default: `''`

#### CRON

Schedule to run the backup script, based on [`supercronic`](https://github.com/aptible/supercronic). You can test the rules [here](https://crontab.guru/#5_*_*_*_*).

Default: `5 * * * *` (run the script at 5 minute every hour)

#### ZIP_ENABLE

Pack all backup files into a compressed file. When set to `'FALSE'`, each backup file will be uploaded independently.

Default: `TRUE`

#### ZIP_PASSWORD

The password for the compressed file. Note that the password will always be used when packing the backup files.

Default: `WHEREISMYPASSWORD?`

#### ZIP_TYPE

Because the `zip` format is less secure, we offer archives in `7z` format for those who seek security.

It should be noted that the password for vaultwarden is encrypted before it is sent to the server. The server does not have plaintext passwords, so the `zip` format is good enough for basic encryption needs.

Default: `zip` (only support `zip` and `7z` formats)

#### BACKUP_KEEP_DAYS

Only keep last a few days backup files in the storage system. Set to `0` to keep all backup files.

Default: `0`

#### BACKUP_FILE_SUFFIX

Each backup file is suffixed by default with `%Y%m%d`. If you back up your vault multiple times a day, that suffix is not unique anymore. This environment variable allows you to append a unique suffix to that date to create a unique backup name.

You can use any character except for `/` since it cannot be used in Linux file names.

This environment variable combines the functionalities of [`BACKUP_FILE_DATE`](#backup_file_date) and [`BACKUP_FILE_DATE_SUFFIX`](#backup_file_date_suffix), and has a higher priority. You can directly use this environment variable to control the suffix of the backup files.

Please use the [date man page](https://man7.org/linux/man-pages/man1/date.1.html) for the format notation.

Default: `%Y%m%d`

#### TIMEZONE

Set your timezone name.

Here is timezone list at [wikipedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

Default: `UTC`

#### PING_URL

Use [healthcheck.io](https://healthchecks.io/) url or similar cron monitoring to perform `GET` requests after a **successful** backup.

#### MAIL_SMTP_ENABLE

The tool uses [heirloom-mailx](https://heirloom.sourceforge.net/mailx.html) to send mail.

Default: `FALSE`

#### MAIL_SMTP_VARIABLES

Because the configuration for sending emails is too complicated, we allow you to configure it yourself.

**We will set the subject according to the usage scenario, so you should not use the `-s` option.**

During testing, we will add the `-v` option to display detailed information.

```text
# STARTLS e.g. Zoho
-S smtp-use-starttls \
-S smtp=smtp://smtp.zoho.com:587 \
-S smtp-auth=login \
-S smtp-auth-user=<my-email-address> \
-S smtp-auth-password=<my-email-password> \
-S from=<my-email-address>
```

```text
# TLSv1.2 e.g. 1und1
-S smtp=smtps://smtp.1und1.de:465 \
-S smtp-auth=login \
-S smtp-auth-user=<my-email-address> \
-S smtp-auth-password=<my-email-password> \
-S from=<my-email-address>
```


For more information, refer to the [Manual](https://heirloom.sourceforge.net/mailx/mailx.1.html) [Tutorial](https://www.systutorials.com/sending-email-from-mailx-command-in-linux-using-gmails-smtp/).

#### MAIL_TO

This specifies the recipient of the notification email.

#### MAIL_WHEN_SUCCESS

Sends an email when the backup is successful.

Default: `TRUE`

#### MAIL_WHEN_FAILURE

Sends an email when the backup fails.

Default: `TRUE`

<details>
<summary><strong>※ Other environment variables</strong></summary>

> **You don't need to change these environment variables unless you know what you are doing.**

#### BACKUP_FILE_DATE

You should use the [`BACKUP_FILE_SUFFIX`](#backup_file_suffix) environment variable instead.

Edit this environment variable only if you explicitly want to change the time prefix of the backup file (e.g. 20220101). **Incorrect configuration may result in the backup file being overwritten by mistake.**

Same rule as [`BACKUP_FILE_DATE_SUFFIX`](#backup_file_date_suffix).

Default: `%Y%m%d`

#### BACKUP_FILE_DATE_SUFFIX

You should use the [`BACKUP_FILE_SUFFIX`](#backup_file_suffix) environment variable instead.

Each backup file is suffixed by default with `%Y%m%d`. If you back up your vault multiple times a day, that suffix is not unique anymore.
This environment variable allows you to append a unique suffix to that date (`%Y%m%d${BACKUP_FILE_DATE_SUFFIX}`) to create a unique backup name.

Note that only numbers, upper and lower case letters, `-`, `_`, `%` are supported.

Please use the [date man page](https://man7.org/linux/man-pages/man1/date.1.html) for the format notation.

Default: `''`

</details>

## Using `.env` file

If you prefer using an env file instead of environment variables, you can map the env file containing the environment variables to the `/.env` file in the container.

```shell
docker run -d \
  --mount type=bind,source=/path/to/env,target=/.env \
  userid0x0/repo-backup:latest
```

## Docker Secrets

As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to the previously listed environment variables. This causes the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files.

```shell
docker run -d \
  -e ZIP_PASSWORD_FILE=/run/secrets/zip-password \
  userid0x0/repo-backup:latest
```

## About Priority

We will use the environment variables first, followed by the contents of the file ending in `_FILE` as defined by the environment variables. Next, we will use the contents of the file ending in `_FILE` as defined in the `.env` file, and finally the values from the `.env` file itself.

## Mail Test

You can use the following command to test mail sending. Remember to replace your SMTP variables.

```shell
docker run --rm -it -e MAIL_SMTP_VARIABLES='<your smtp variables>' userid0x0/repo-backup:latest mail <mail send to>

# Or

docker run --rm -it -e MAIL_SMTP_VARIABLES='<your smtp variables>' -e MAIL_TO='<mail send to>' userid0x0/repo-backup:latest mail
```

## Advance

- [Multiple remote destinations](docs/multiple-remote-destinations.md)
- [Manually trigger a backup](docs/manually-trigger-a-backup.md)

## License

MIT
