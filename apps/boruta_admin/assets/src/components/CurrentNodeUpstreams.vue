<template>
  <div class="ui current-node-upstreams segment">
    <div class="ui big grey fluid label">{{ currentNodeName }}</div>
    <div class="ui relaxed divided list" v-if="currentNodeUpstreams.length">
      <router-link
        class="item"
        v-for="currentUpstream in currentNodeUpstreams"
        :class="{ 'edited-upstream': isEditedUpstream(currentUpstream) }"
        :to="{ name: 'edit-upstream', params: { upstreamId: currentUpstream.id } }"
        :key="currentUpstream.id">
        <div class="content">
          <div class="header">{{ currentUpstream.baseUrl }}</div>
          <div class="meta" v-if="currentUpstream.virtual_host">
            {{ currentUpstream.virtual_host }}
          </div>
          <div class="description">
            <span v-for="path in currentUpstream.uris" class="ui teal label" :key="path.uri">
              {{ path.uri }}
            </span>
          </div>
        </div>
      </router-link>
    </div>
    <div class="ui small message" v-else>
      No upstreams configured for this node.
    </div>
    <router-link
      :disabled="!editedUpstreamId"
      :to="{ name: 'new-upstream', query: { node_name: currentNodeName } }"
      class="ui primary fluid button">Create an upstream</router-link>
  </div>
</template>

<script>
import Upstream from '../models/upstream.model'

export default {
  name: 'current-node-upstreams',
  props: ['nodeName', 'editedUpstreamId'],
  data () {
    return {
      upstreams: {}
    }
  },
  mounted () {
    this.getUpstreams()
  },
  computed: {
    currentNodeName () {
      return this.nodeName || 'global'
    },
    currentNodeUpstreams () {
      return this.upstreams[this.currentNodeName] || []
    }
  },
  methods: {
    getUpstreams () {
      Upstream.all().then((upstreams) => {
        this.upstreams = upstreams
      })
    },
    isEditedUpstream (upstream) {
      return this.editedUpstreamId && `${upstream.id}` === `${this.editedUpstreamId}`
    }
  }
}
</script>

<style scoped lang="scss">
.current-node-upstreams {
  .label {
    margin: .125rem;
  }

  .message {
    margin-bottom: 0;
  }

  .item {
    padding: .3em .5em!important;
    border: 1px solid transparent!important;
    border-left: 3px solid transparent!important;
  }

  .item.edited-upstream {
    background: color-mix(
      in srgb,
      var(--theme-primary, #2185d0) 16%,
      var(--theme-surface, #fff)
    );
    border: 1px solid var(--theme-primary, #2185d0)!important;
    border-left: 3px solid var(--theme-primary, #2185d0)!important;
    border-radius: calc(var(--theme-radius, 8px) * .5);
    color: var(--theme-text, inherit);
    transition: background .15s ease, box-shadow .15s ease;

    .header, .meta {
      color: var(--theme-text, inherit)!important;
    }

    .header {
      font-weight: 800;
    }

    &:hover {
      background: color-mix(
        in srgb,
        var(--theme-primary, #2185d0) 24%,
        var(--theme-surface, #fff)
      );
    }
  }
}
</style>
