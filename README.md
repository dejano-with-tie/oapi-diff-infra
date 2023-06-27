# oapi-diff

> Track openapi spec changes with ease.

```mermaid
sequenceDiagram

participant qadev
participant apidev
participant github
participant s3
participant lambda as lambda-spec-diff

apidev ->> github: push openapi spec changes
github ->> github: start CI pipeline
github ->> s3: store openapi spec version
lambda ->> s3: fetch latest 2 versions of a spec
lambda ->> lambda: diff
lambda ->> s3: store diff
qadev -) s3: openapi spec diff
qadev -) s3: openapi versioned spec
```


> **Disclaimer**: this is just a proof of concept, don't mind the ugly. 
### Tools

- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [Swagger Diff 0](https://github.com/Sayi/swagger-diff)
- [Swagger Diff 1](https://github.com/OpenAPITools/openapi-diff)
- [Swagger Diff 2](https://bitbucket.org/atlassian/openapi-diff/src/master/)
