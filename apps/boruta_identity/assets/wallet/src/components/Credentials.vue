<template>
  <div class="credentials">
    <div class="ui container">
      <div class="ui cards">
        <div class="card" v-for="credential in credentials">
          <div class="content">
            <div class="header">
              {{ credential.credentialId }}
            </div>
            <div class="meta">
              {{ credential.format }}
            </div>
            <div class="description">
              <div class="ui list">
                <div class="item" v-for="claim in credential.claims">
                  <div class="content">
                    <a class="header">{{ claim.key }}</a>
                    <div class="description">{{ claim.value }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="extra content">
            <div class="ui fluid buttons">
              <button class="ui basic red button" @click="$emit('deleteCredential', credential)">
              {{ deleteLabel || 'Delete' }}
              </button>
              <button class="ui basic blue button" @click="showCredential(credential)">Show</button>
            </div>
          </div>
        </div>
      </div>
      <div class="credentials-actions" v-if="exportable">
        <button
          class="ui violet button"
          :class="{ loading: exporting }"
          :disabled="exporting || !credentials.length"
          @click="showExportPrompt()"
        >
          <i class="download icon"></i>
          Export credentials
        </button>
        <button
          class="ui basic violet button"
          :class="{ loading: importing }"
          :disabled="importing"
          @click="selectImportFile()"
        >
          <i class="upload icon"></i>
          Import credentials
        </button>
        <input
          ref="importFileInput"
          type="file"
          accept=".jwe,application/jose,text/plain"
          class="import-file-input"
          @change="handleImportFileSelection"
        />
      </div>
    </div>
    <div class="modal-wrapper" v-if="importPromptVisible">
      <div class="ui modal visible active">
        <div class="header">
          Decrypt credentials import
        </div>
        <form class="content" @submit.prevent="importCredentials()">
          <div class="ui form">
            <div class="field">
              <label>Password</label>
              <input
                ref="importPasswordInput"
                type="password"
                autocomplete="current-password"
                v-model="importPassword"
              />
            </div>
          </div>
        </form>
        <div class="actions">
          <button class="ui basic button" type="button" @click="hideImportPrompt()">
            Cancel
          </button>
          <button
            class="ui positive right button"
            type="button"
            :class="{ loading: importing }"
            :disabled="importing || !importPassword"
            @click="importCredentials()"
          >
            Import
          </button>
        </div>
      </div>
    </div>
    <div class="modal-wrapper" v-if="exportPromptVisible">
      <div class="ui modal visible active">
        <div class="header">
          Encrypt credentials export
        </div>
        <form class="content" @submit.prevent="exportCredentials()">
          <div class="ui form">
            <div class="field">
              <label>Password</label>
              <input
                ref="exportPasswordInput"
                type="password"
                autocomplete="new-password"
                v-model="exportPassword"
              />
            </div>
          </div>
        </form>
        <div class="actions">
          <button class="ui basic button" type="button" @click="hideExportPrompt()">
            Cancel
          </button>
          <button
            class="ui positive right button"
            type="button"
            :class="{ loading: exporting }"
            :disabled="exporting || !exportPassword"
            @click="exportCredentials()"
          >
            Export
          </button>
        </div>
      </div>
    </div>
    <div class="modal-wrapper" v-if="credential">
      <div class="ui modal visible active">
        <div class="header">
          {{ credential.credential_configuration_id }} credential JWT
        </div>
        <div class="content">
          <div class="description">
            <p class="ui segment"><pre>{{ credential.credential }}</pre></p>
          </div>
        </div>
        <div class="actions">
          <button class="ui positive right button" @click="hideCredential()">
            Done
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue'
import { CompactEncrypt, compactDecrypt } from 'jose'

const textEncoder = new TextEncoder()
const textDecoder = new TextDecoder()

export default defineComponent({
  name: 'CredentialsView',
  props: ['credentials', 'deleteLabel', 'exportable'],
  data () {
    return {
      formattedCredentials: [],
      credential: null,
      exporting: false,
      exportPromptVisible: false,
      exportPassword: '',
      importing: false,
      importPromptVisible: false,
      importPassword: '',
      importJwe: ''
    }
  },
  methods: {
    showCredential (credential) {
      this.credential = credential
    },
    hideCredential (credential) {
      this.credential = null
    },
    showExportPrompt () {
      this.exportPromptVisible = true
      this.$nextTick(() => this.$refs.exportPasswordInput?.focus())
    },
    hideExportPrompt () {
      this.exportPromptVisible = false
      this.exportPassword = ''
    },
    selectImportFile () {
      this.$refs.importFileInput?.click()
    },
    async handleImportFileSelection (event) {
      const file = event.target.files[0]
      event.target.value = ''

      if (!file) return

      try {
        this.importJwe = (await file.text()).trim()
        this.importPromptVisible = true
        this.$nextTick(() => this.$refs.importPasswordInput?.focus())
      } catch (error) {
        console.error(error)
        window.alert('Unable to read credentials import file.')
      }
    },
    hideImportPrompt () {
      this.importPromptVisible = false
      this.importPassword = ''
      this.importJwe = ''
    },
    async importCredentials () {
      if (!this.importPassword || !this.importJwe) return

      this.importing = true

      try {
        const { plaintext } = await compactDecrypt(this.importJwe, textEncoder.encode(this.importPassword), {
          keyManagementAlgorithms: ['PBES2-HS256+A128KW'],
          contentEncryptionAlgorithms: ['A256GCM']
        })
        const payload = JSON.parse(textDecoder.decode(plaintext))
        const credentials = this.parseImportedCredentials(payload)

        this.$emit('importCredentials', credentials)
        this.hideImportPrompt()
      } catch (error) {
        console.error(error)
        window.alert('Unable to decrypt credentials import. Check the file and password.')
      } finally {
        this.importing = false
        this.importPassword = ''
      }
    },
    parseImportedCredentials (payload) {
      if (payload?.type != 'boruta-wallet-credentials' || !Array.isArray(payload.credentials)) {
        throw new Error('Unsupported credentials import file.')
      }

      return payload.credentials.map(({ credentialId, format, credential }) => {
        if (!credentialId || !format || !credential) {
          throw new Error('Invalid credentials import file.')
        }

        return { credentialId, format, credential }
      })
    },
    async exportCredentials () {
      if (!this.exportPassword) return

      this.exporting = true

      try {
        const payload = JSON.stringify({
          type: 'boruta-wallet-credentials',
          exported_at: new Date().toISOString(),
          credentials: this.credentials
        })
        const jwe = await new CompactEncrypt(textEncoder.encode(payload))
          .setProtectedHeader({
            alg: 'PBES2-HS256+A128KW',
            enc: 'A256GCM',
            cty: 'application/json',
            p2c: 100000
          })
          .encrypt(textEncoder.encode(this.exportPassword))

        this.exportFile(jwe)
        this.hideExportPrompt()
      } catch (error) {
        console.error(error)
        window.alert('Unable to encrypt credentials export.')
      } finally {
        this.exporting = false
        this.exportPassword = ''
      }
    },
    exportFile (jwe) {
      const blob = new Blob([jwe], { type: 'application/jose' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')

      link.href = url
      link.download = `boruta-wallet-credentials-${new Date().toISOString().slice(0, 10)}.jwe`
      document.body.appendChild(link)
      link.click()
      link.remove()
      URL.revokeObjectURL(url)
    }
  }
})
</script>

<style scoped lang="scss">
.ui.cards {
  justify-content: center;
}
.credentials-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
  margin-top: 1.5rem;
}
.import-file-input {
  display: none;
}
.card .item {
  overflow: hidden

}
pre {
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow: hidden;
  overflow-y: scroll;
  max-height: 60vh;
}
.modal-wrapper {
  z-index: 1000;
  position: fixed;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 1em;
}
</style>
