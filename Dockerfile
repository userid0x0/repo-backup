FROM rclone/rclone:1.62.2

LABEL "repository"="https://github.com/userid0x0/repo-backup" \
  "homepage"="https://github.com/userid0x0/repo-backup"

ARG USER_NAME="backuptool"
ARG USER_ID="1100"

ENV LOCALTIME_FILE="/tmp/localtime"

COPY scripts/*.sh /app/

RUN chmod +x /app/*.sh \
  && mkdir -m 777 /repo \
  && apk add --no-cache 7zip bash heirloom-mailx subversion supercronic tzdata \
  && ln -sf "${LOCALTIME_FILE}" /etc/localtime \
  && addgroup -g "${USER_ID}" "${USER_NAME}" \
  && adduser -u "${USER_ID}" -Ds /bin/sh -G "${USER_NAME}" "${USER_NAME}"

ENTRYPOINT ["/app/entrypoint.sh"]
