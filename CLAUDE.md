# Family Tree

Cross-platform private family tree application.

## Platforms

- iOS
- Android

## Technology

- Flutter
- Dart
- Riverpod
- Drift / SQLite
- Supabase
- PostgreSQL

## Architecture

Feature-oriented architecture.

UI
↓
Application
↓
Domain
↓
Repository
↓
Local / Remote data sources

Domain layer must not depend on Flutter,
Supabase, or Drift.

## Core entities

- Family
- Person
- Relationship
- FamilyMember

Relationships are modeled separately.

Do NOT store:

- father_id
- mother_id
- spouse_id

inside Person.

## Relationship types

Initial V1:

- parentChild
- spouse

Architecture must allow additional relationship
types later.

## Development rules

- Do not modify unrelated files.
- Prefer small changes.
- Add tests for domain logic.
- Run tests after modifications.
- Run dart analyze.
- Explain architectural changes before implementing them.
- Do not add dependencies without explaining why.
- Never commit secrets.
- Never put API keys directly in source code.

## Cost philosophy

This is a small private application.

Optimize for:

1. maintainability
2. low operational cost
3. simplicity
4. offline capability

Avoid unnecessary infrastructure.

Do not introduce:

- microservices
- Redis
- Kubernetes
- custom backend

unless clearly justified.