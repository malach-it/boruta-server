<template>
  <div class="client-list">
    <div class="ui container">
      <h1>Clients</h1>
      <div class="ui two column centered grid">
        <div class="column">
          <div v-for="client in clients" class="ui big client segments" :key="client.id">
            <div class="ui teal segment"><strong>Client ID:</strong> {{ client.id }}</div>
            <div class="ui segment"><strong>Client secret:</strong> {{ client.secret }}</div>
            <div class="ui segment"><strong>Client redirect URI:</strong> {{ client.redirect_uri }}</div>
            <div class="ui center aligned segment">
              <router-link
                :to="{ name: 'edit-client', params: { clientId: client.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteClient(client)" class="ui tiny red button">delete</a>
            </div>
          </div>
          <div class="actions">
            <router-link :to="{ name: 'new-client' }" class="ui blue big button">Add an client</router-link>
          </div>
        </div>
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
