import angularPreset from 'conventional-changelog-angular'

const { transform: angularTransform } = angularPreset().writer

const HIDDEN_TYPES = new Set(['chore', 'test', 'ci', 'build'])

const headerPartial = `## {{#if @root.linkCompare~}}
  [{{version}}](
  {{~#if @root.repository~}}
    {{~#if @root.host}}
      {{~@root.host}}/
    {{~/if}}
    {{~#if @root.owner}}
      {{~@root.owner}}/
    {{~/if}}
    {{~@root.repository}}
  {{~else}}
    {{~@root.repoUrl}}
  {{~/if~}}
  /compare/{{previousTag}}...{{currentTag}})
{{~else}}
  {{~version}}
{{~/if}}{{#if title}} "{{title}}"
{{~/if}}{{#if date}} ({{date}})
{{/if}}
`

const commitPartial = `* {{#if scope}}**{{scope}}:** {{/if}}{{#if subject}}{{subject}}{{else}}{{header}}{{/if}}
`

export default {
  writerOpts: {
    headerPartial,
    commitPartial,
    transform (commit, context) {
      if (HIDDEN_TYPES.has(commit.type)) {
        return false
      }
      return angularTransform(commit, context)
    },
  },
}
