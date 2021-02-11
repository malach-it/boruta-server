<template>
  <div class="client-list">
    <div class="ui container">
      <h1>Clients</h1>
      <div v-for="client in clients" class="ui big client segments" :key="client.id">
        <div class="ui segment">
          <div class="actions">
            <router-link
              :to="{ name: 'edit-client', params: { clientId: client.id } }"
              class="ui tiny blue button">edit</router-link>
            <a v-on:click="deleteClient(client)" class="ui tiny red button">delete</a>
          </div>
          <p><strong>Client ID:</strong> {{ client.id }}</p>
          <p><strong>Client secret:</strong> {{ client.secret }}</p>
          <p><strong>Client redirect URIs:</strong> {{ client.redirect_uris.map(({ uri }) => uri).join(', ') }}</p>
          <p v-if="client.authorize_scope">
            <span v-for="scope in client.authorized_scopes" class="ui olive label" :key="scope.model.id">
              {{ scope.model.name }}
            </span>
          </p>
        </div>
      </div>
      <div class="main actions">
        <router-link :to="{ name: 'new-client' }" class="ui teal big button">Add a client</router-link>
      </div>
    </div>
  </div>
</template>

<script>
import Client from '@/models/client.model'

export default {
  name: 'client-list',
  data () {
    return { clients: [] }
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
      if (confirm('Are yousure ?')) {
        client.destroy().then(() => {
          this.clients.splice(this.clients.indexOf(client), 1)
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
</style>
