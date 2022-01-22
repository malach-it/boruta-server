<template>
  <div class="text-editor">
    <div class="editor lang-markup" ref="editor"></div>
  </div>
</template>

<script>
import { CodeJar } from 'codejar'
import { withLineNumbers } from 'codejar/linenumbers'
import { highlight, languages } from 'prismjs'

export default {
  name: 'TextEditor',
  props: ['content'],
  mounted () {
    const highlightFunc = (editor) => {
      const code = editor.textContent

      editor.innerHTML = highlight(code, languages.markup, 'markup')
    }

    const editor = CodeJar(this.$refs.editor, withLineNumbers(highlightFunc), {
      tab: ' '.repeat(2),
      spellcheck: false
    })

    editor.onUpdate(code => {
      this.$emit('codeUpdate', code)
    })

    this.editor = editor
  },
  watch: {
    content (code) {
      this.editor.updateCode(code)
    }
  }
}
</script>

<style scoped lang="scss">
.text-editor {
  height: 100%;
  overflow: hidden;
}
</style>
