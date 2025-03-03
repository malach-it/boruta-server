<template>
  <div class="credentials">
    <div class="ui container">
      <div class="ui center aligned segment" v-if="displayDelete">
        <h2>You are about to remove a credential from your wallet</h2>
        <div class="ui fluid two buttons">
          <button class="ui orange button" @click="displayDelete = false">Abort</button>
          <button class="ui green button" @click="confirmDelete()">Proceed</button>
        </div>
      </div>
      <div class="ui cards">
        <div class="card" v-for="credential in credentials">
          <div class="content">
            <!-- <img class="right floated mini ui image" src="/images/avatar/large/elliot.jpg"> -->
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
              <button class="ui basic red button" @click="deleteCredential(credential)">Delete</button>
              <button class="ui basic blue button" @click="showCredential(credential)">Show</button>
            </div>
          </div>
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
          <button class="ui positive right labeled icon button" @click="hideCredential()">
            Done
            <i class="checkmark icon"></i>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue'
import { mapGetters } from 'vuex'
import { decodeSdJwt } from '@sd-jwt/decode'

export default defineComponent({
  name: 'CredentialsView',
  components: {},
  data () {
    return {
      formattedCredentials: [],
      credential: null,
      credentialToDelete: null,
      displayDelete: false
    }
  },
  computed: {
    ...mapGetters(['credentials'])
  },
  methods: {
    showCredential (credential) {
      this.credential = credential
    },
    hideCredential () {
      this.credential = null
    },
    deleteCredential (credential) {
      this.credentialToDelete = credential
      window.addEventListener('delete_credential-request~' + this.credentialToDelete.credential, () => {
        this.displayDelete = true
      })
      this.$store.commit('deleteCredential', credential)
    },
    confirmDelete () {
      window.dispatchEvent(new Event('delete_credential-approval~' + this.credentialToDelete.credential))
      this.displayDelete = false
    },
  }
})
</script>

<style scoped lang="scss">
.ui.cards {
  justify-content: center;
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

