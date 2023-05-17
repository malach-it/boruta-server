<template>
  <div class="client-list">
    <Toaster :active="deleted" message="Client has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <router-link :to="{ name: 'new-client' }" class="ui violet main create button">Add a client</router-link>
    <div class="container">
      <div class="ui info message">
        Clients are here relying parties as defined in <a target="_blank" href="https://datatracker.ietf.org/doc/html/rfc6749#section-1.1">OAuth 2.0 RFC</a>. They are the applications that require a priviledge access to a HTTP service secured by the Boruta authorization server.
      </div>
      <div class="ui two column clients stackable grid" v-if="clients.length">
        <div v-for="client in clients" class="ui column" :key="client.id">
          <div class="ui client highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-client', params: { clientId: client.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteClient(client)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item" v-if="client.name">
                <span class="header">Name</span>
                <span class="description">{{ client.name }}</span>
              </div>
              <div class="item">
                <span class="header">Client ID</span>
                <span class="description">{{ client.id }}</span>
              </div>
              <div class="item">
                <span class="header">Client secret</span>
                <span class="description">
                  <div class="ui form field">
                    <div class="ui left icon input">
                      <input disabled :type="client.passwordVisible ? 'text' : 'password'" v-model="client.secret" />
                      <i class="eye icon" :class="{ 'slash': client.passwordVisible }" @click="passwordVisibilityToggle(client)"></i>
                    </div>
                  </div>
                </span>
              </div>
              <div class="item">
                <span class="header">Public key</span>
                <pre class="description">{{ client.public_key }}</pre>
              </div>
              <div class="item" v-if="client.redirect_uris.length">
                <span class="header">Client redirect URIs</span>
                <span class="description" v-for="uri in client.redirect_uris" :key="uri.uri">
                  {{ uri.uri }}
                </span>
              </div>
              <div class="item" v-if="client.authorize_scope">
                <span class="header">Authorized scopes</span>
                <span class="description">
                  <span v-for="scope in client.authorized_scopes" class="ui teal label" :key="scope.model.id">
                    {{ scope.model.name }}
                  </span>
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Client from '../../models/client.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'client-list',
  components: {
    Toaster
  },
  data () {
    return {
      clients: [] ,
      deleted: false,
      errorMessage: false
    }
  },
  mounted () {
    this.getClients()
  },
  methods: {
    getClients () {
      Client.all().then((clients) => {
        this.clients = clients
      })
    },
    deleteClient (client) {
      if (!confirm('Are you sure ?')) return
      this.deleted = false
      this.errorMessage = false
      client.destroy().then(() => {
        this.deleted = true
        this.clients.splice(this.clients.indexOf(client), 1)
      }).catch((error) => {
        this.errorMessage = error.message
      })
    },
    passwordVisibilityToggle (client) {
      client.passwordVisible = !client.passwordVisible
    }
  }
}
</script>

<style scoped lang="scss">
.input {
  display: flex;
  input[disabled] {
    opacity: 1!important;
    border: none!important;
    background: inherit!important;
    padding: 0;
  }
}
</style>
