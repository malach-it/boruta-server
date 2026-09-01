<template>
  <div class="ui current-node-upstreams segment">
    <h4 class="ui header">Current node upstreams</h4>
    <div class="ui small grey label">{{ currentNodeName }}</div>
    <div class="ui small error message" v-if="error">
      {{ error }}
    </div>
    <div class="ui relaxed divided list" v-else-if="currentNodeUpstreams.length">
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
  </div>
</template>

<script>
import Upstream from '../models/upstream.model'

export default {
  name: 'current-node-upstreams',
  props: ['nodeName', 'editedUpstreamId'],
  data () {
    return {
      upstreams: {},
      error: null
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
        this.error = null
      }).catch((error) => {
        this.error = error.response?.data?.message || error.message
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
  clear: both;
  margin-top: 1rem;

  .label {
    margin: .125rem;
  }

  .message {
    margin-bottom: 0;
  }

  .item.edited-upstream {
    position: relative;
    margin-left: -.75rem;
    padding: .75rem;
    background: color-mix(
      in srgb,
      var(--theme-accent, #2185d0) 16%,
      var(--theme-surface, #fff)
    );
    border-left: 3px solid var(--theme-accent, #2185d0);
    border-radius: calc(var(--theme-radius, 8px) * .5);
    box-shadow: inset 0 0 0 1px color-mix(
      in srgb,
      var(--theme-accent, #2185d0) 34%,
      transparent
    );
    color: var(--theme-text, inherit);
    transition: background .18s ease, box-shadow .18s ease;

    .header, .meta {
      color: var(--theme-text, inherit)!important;
    }

    .header {
      font-weight: 800;
    }

    &:hover {
      background: color-mix(
        in srgb,
        var(--theme-accent, #2185d0) 24%,
        var(--theme-surface, #fff)
      );
      box-shadow: inset 0 0 0 1px var(--theme-accent, #2185d0);
    }
  }
}
</style>
