# AGENTS.md — Agent Guidance for paperless-custom

This is a custom fork of paperless-ngx with frontend-only performance fixes. The backend (`src/documents/`, `src/paperless_mail/`) is untouched upstream code.

## Project Structure

```
paperless-custom/
├── src/                 # Backend (untouched upstream)
├── src-ui/              # Frontend (our changes live here)
│   ├── src/app/         # Angular app source
│   ├── package.json     # pnpm-based (NOT npm)
│   ├── angular.json     # Angular CLI config
│   ├── jest.config.js   # Jest test config
│   └── .eslintrc.json   # ESLint config
└── .forgejo/workflows/  # CI/CD (Forgejo Actions)
```

## Commands

### Install & Run

```bash
cd src-ui
pnpm install           # MUST use pnpm (enforced by preinstall hook)
pnpm start             # Dev server at http://localhost:4200
```

### Build & Test

```bash
pnpm build             # Production build (outputs to src/documents/static/frontend/)
pnpm test              # Run all tests (Jest, --no-watch, with coverage)
pnpm lint              # Run ESLint
```

### Running a Single Test

```bash
# By file path
pnpm test -- --testPathPattern="filter-editor.component.spec.ts"

# By test name
pnpm test -- --testNamePattern="should do something"

# Watch mode (for development)
pnpm test -- --watch
```

### Debugging Tests

```bash
# Run specific test file in watch mode
pnpm test -- --watch --testPathPattern="filter-editor"

# Debug with console output
pnpm test -- --verbose --testPathPattern="filter-editor"
```

## Code Style Guidelines

### Components

- **Standalone components** with `imports` array (not `declarations`)
- **Prefix**: `pngx` (e.g., `<pngx-filter-editor>`)
- **Selector type**: element (kebab-case), attribute (camelCase for directives)
- Use `@Component({ selector: '...', imports: [...] })` pattern
- Use `inject()` function for dependency injection, not constructor injection

### Imports

Organize imports in this order:
1. Angular core (`@angular/core`, `@angular/common`, etc.)
2. Angular ecosystem (`@ng-bootstrap/ng-bootstrap`, etc.)
3. Third-party libraries (`rxjs`, `ngx-bootstrap-icons`, etc.)
4. Project imports (`src/app/...`)

Use explicit imports (no barrel files like `index.ts`).

```typescript
import { Component, Input, Output, inject } from '@angular/core'
import { FormsModule } from '@angular/forms'
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap'
import { Observable, Subject, from } from 'rxjs'
import { map, switchMap, takeUntil } from 'rxjs/operators'
import { Document } from 'src/app/data/document'
import { FilterRule } from 'src/app/data/filter-rule'
import { PermissionsService } from 'src/app/services/permissions.service'
import { DocumentService } from 'src/app/services/rest/document.service'
```

### Types & TypeScript

- Target: ES2022, module: es2020
- `useDefineForClassFields: false` (Angular class fields)
- Explicit return types for methods
- Use interfaces for data structures (not classes)
- Use `any` sparingly — prefer explicit types or `unknown`

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Components | PascalCase | `FilterEditorComponent` |
| Services | PascalCase | `DocumentService` |
| Directives | PascalCase | `IfPermissionsDirective` |
| Variables | camelCase | `filterRules`, `documentCounts` |
| Constants | UPPER_SNAKE_CASE | `FILTER_TITLE`, `DEFAULT_TEXT_FILTER` |
| Files | kebab-case | `filter-editor.component.ts` |
| CSS classes | kebab-case | `.filter-editor` |

### Template Style

- Use strict template checking
- Prefer `*ngIf`/`*ngFor` over `@if`/`@for` (upstream uses Angular 21 but template control flow varies)
- Use `$localize` for i18n strings: `` $localize`Title: ${rule.value}` ``

### RxJS Patterns

```typescript
// Cleanup pattern
private unsubscribeNotifier: Subject<any> = new Subject()

ngOnDestroy() {
  this.unsubscribeNotifier.next(true)
}

// In subscriptions
this.someObservable.pipe(
  takeUntil(this.unsubscribeNotifier),
  debounceTime(400),
  distinctUntilChanged()
).subscribe(value => { ... })
```

### Error Handling

```typescript
// In services/subscriptions
this.http.get(...).pipe(
  takeUntil(this.unsubscribeNotifier)
).subscribe({
  next: (result) => { ... },
  error: (error) => { this.handleError(error) }
})

// In components with async pipe
async$().pipe(
  catchError(error => of(fallbackValue))
)
```

### Testing

- Use Jest (via `@angular-builders/jest`)
- Test file location: `<component>.spec.ts` alongside component
- Use `TestBed.configureTestingModule` with `provideHttpClientTesting`
- Pattern: `fakeAsync` + `tick()` for async operations

```typescript
it('should do something', fakeAsync(() => {
  component.someMethod()
  tick(100)
  expect(component.result).toBe('expected')
}))
```

### CSS/SCSS

- Component styles in `.scss` files, referenced via `styleUrls`
- Use SCSS variables from global `styles.scss`
- Prefix with component name to avoid conflicts: `.filter-editor__item`

## Important Notes

### Lazy Loading Fix

Our key performance fix is in `src-ui/src/app/components/document-list/filter-editor/filter-editor.component.ts`. When modifying filter dropdowns:

- **Do NOT load all items in `ngOnInit`** — this causes 27s+ load times with thousands of tags
- **Use lazy loading** — load items in dropdown open handlers (e.g., `onTagsDropdownOpen()`)
- Keep the lazy loading pattern when merging upstream

### Preserving Our Changes

When syncing with upstream:
- Backend (`src/documents/`, `src/paperless_mail/`) is untouched — safe to update
- Our changes are frontend-only (`src-ui/src/app/...`)
- If upstream modifies our files, preserve our lazy loading implementation

### CI/CD

- Branch: `dev` triggers Forgejo Actions → Docker build → registry
- Image pushed to `git-forgejo.k-lab.lan:3000/timkjr/paperless-custom`
- Production tag: `:custom-fix`