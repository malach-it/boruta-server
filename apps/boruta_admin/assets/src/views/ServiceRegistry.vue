<template>
  <div id="service-registry">
    <div class="container">
      <div class="ui two column nodes stackable grid" v-if="nodes.length">
        <div v-for="node in nodes" class="ui column" :key="node.id">
          <div class="ui node highlightable segment">
            <div class="ui attribute list">
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
    }
  }
}
</script>
