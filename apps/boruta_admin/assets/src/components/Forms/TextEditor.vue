<template>
  <div class="field text-editor">
    <div class="editor lang-markup" ref="editor">{{ code }}</div>
  </div>
</template>

<script>
import { CodeJar } from 'codejar'
import { withLineNumbers } from 'codejar/linenumbers'
import { highlight, languages } from 'prismjs'

export default {
  name: 'TextEditor',
  props: ['content'],
  data () {
    return {
      code: this.content
    }
  },
  mounted () {
    const highlightFunc = (editor) => {
      const code = editor.textContent

      editor.innerHTML = highlight(code, languages.markup, 'markup')
      console.log(languages.markup)
    }

    const editor = CodeJar(this.$refs.editor, withLineNumbers(highlightFunc), {
      tab: ' '.repeat(2),
      spellcheck: false
    })

      editor.onUpdate(code => {
          this.$emit('codeUpdate', code)
          })
  }
}
</script>

<style scoped lang="scss">
.field.text-editor {
  height: 100%;
}
</style>
