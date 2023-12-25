<template>
  <div id="service-registry">
    <div class="container">
      <div class="ui three column nodes stackable grid" v-if="nodes.length">
        <div v-for="node in nodes" class="ui column" :key="node.id">
          <div class="ui node highlightable segment" :class="{'error message': node.status == 'unreachable'}">
            <div class="actions">
              <a v-on:click="deleteNode(node)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Status</span>
                <span class="description">{{ node.status }}</span>
              </div>
              <div class="item">
                <span class="header">Node ID</span>
                <span class="description">{{ node.id }}</span>
              </div>
              <div class="item">
                <span class="header">IP</span>
                <span class="description">{{ node.ip }}</span>
              </div>
              <div class="item">
                <span class="header">Name</span>
                <span class="description">{{ node.name }}</span>
              </div>
              <div class="item">
                <span class="header">Connections</span>
                <span class="description" v-for="connection in node.connections">
                <span :class="{'green': connection.status == 'up', 'red': connection.status != 'up'}" class="ui label">{{ connection.status }}</span>
                {{ connection.to.ip }} | {{ connection.to.name }}
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
import Node from '../models/node.model'

export default {
  name: 'service-registry',
  data () {
    return {
      nodes: []
    }
  },
  mounted () {
    this.getNodes()
  },
  methods: {
    getNodes () {
      Node.all().then(nodes => {
        this.nodes = nodes
      })

      setTimeout(() => {
        this.getNodes()
      }, 5000)
    },
    deleteNode(node) {
      node.destroy().then(() => {
        this.nodes.splice(this.nodes.indexOf(node), 1)
      })
    }
  }
}
</script>
