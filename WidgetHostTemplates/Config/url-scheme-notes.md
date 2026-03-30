# URL Scheme Setup

Register this custom URL scheme on the main app target:

- `projectresume`

The widget uses URLs in this form:

```text
projectresume://open-project?id=<uuid>
```

Once registered, the existing app code already handles this route through `.onOpenURL`.
