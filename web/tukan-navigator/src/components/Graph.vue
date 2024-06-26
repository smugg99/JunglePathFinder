<template>
  <input type="file" ref="fileInput" @change="loadGraphFromFile" style="display: none;">
  <v-container fluid class="fill-height">
    <v-row class="fill-height">
      <v-col class="fill-height">
        <!-- SVG container with relative positioning -->
        <div class="svg-container">
          <!-- SVG graph with absolute positioning -->
          <svg ref="svg" class="graph-svg" :class="{ 'hand-cursor': mode === 'pan' }" @mousedown="startInteraction"
            @touchstart="startInteraction" @mouseup="stopInteraction" @mouseleave="stopInteraction"
            @touchend="stopInteraction" @mousemove="handleMouseOver" @touchmove="handleTouchMove"
            @click="handleSvgClick">
            <g :transform="`translate(${panX}, ${panY})`">
              <!-- Define grid pattern -->
              <defs>
                <pattern id="gridPattern" width="40" height="40" patternUnits="userSpaceOnUse">
                  <rect width="40" height="40" :fill="currentTheme === 'dark' ? '#2c2c2c' : '#f0f0f0'" />
                  <path d="M 40 0 L 0 0 0 40" fill="none" :stroke="currentTheme === 'dark' ? '#888888' : '#cccccc'"
                    stroke-width="1" />
                </pattern>
              </defs>
            </g>

            <g :transform="`translate(${panX}, ${panY})`">
              <!-- Apply grid pattern as background -->
              <rect height="100000" width="100000" x="-50000" y="-50000" fill="url(#gridPattern)" />
            </g>

            <!-- Existing SVG content -->
            <g :transform="`translate(${panX}, ${panY})`">
              <!-- Render existing edges -->
              <Edge v-for="edge in validEdges" :key="'edge-' + edge.id" :from="findNode(edge.from)"
                :to="findNode(edge.to)" :edge="edge"
                :highlighted="(selectedEdgeId === edge.id || highlightedEdgeId === edge.id) && (mode === 'edit' || mode === 'remove')"
                @select="handleEdgeSelect(edge)" />
              />
              <!-- Render existing nodes -->
              <Node v-for="node in nodes" :key="'node-' + node.id" :id="node.id" :x="node.x" :y="node.y"
                :selected="node.id === selectedNodeId || node.id === edgeStartNode"
                :highlighted="node.id === hoveredNodeId || node.id === selectedNodeIdInEditMode"
                :traversed="node.traversed" :mode="mode" @select="selectNode"
                @mousedown.stop="startNodeDrag($event, node.id)" @touchstart.stop="startNodeDrag($event, node.id)" />
              />
            </g>

            <!-- Ghost element for new edge -->
            <line v-if="mode === 'addEdge' && edgeStartNode && hoveredNodeId" :x1="findNode(edgeStartNode).x + panX"
              :y1="findNode(edgeStartNode).y + panY" :x2="findNode(hoveredNodeId).x + panX"
              :y2="findNode(hoveredNodeId).y + panY" :stroke="currentTheme === 'dark' ? '#ffffff' : '#000000'"
              :opacity="currentTheme === 'dark' ? '0.5' : '0.3'" z-index="1" stroke-dasharray="5,5"
              pointer-events="none" />

            <!-- Ghost element for new node -->
            <circle v-if="mode === 'add' && addNodeHovered" :cx="addNodeHovered.x + panX" :cy="addNodeHovered.y + panY"
              r="20" fill="transparent" :stroke="currentTheme === 'dark' ? '#ffffff' : '#000000'"
              :opacity="currentTheme === 'dark' ? '0.5' : '0.3'" z-index="1" stroke-dasharray="5,5"
              pointer-events="none" />

            <g :transform="`translate(${toucanX - 24}, ${toucanY - 24})`">
              <Toucan v-if="toucanVisible" :backgroundColor="currentTheme === 'dark' ? '#212121' : '#fefeff'"
                :bodyColor="currentTheme === 'dark' ? '#fefeff' : '#212121'" />
            </g>
          </svg>

          <div class="button-group left">
            <v-btn v-tooltip:end="'Save graph to file'" @mousedown.stop="saveGraphToFile();"
              :size="isMobile ? 'small' : 'large'" density="default">
              <v-icon>mdi-content-save</v-icon> Save
            </v-btn>

            <input type="file" id="fileInput" @change="loadGraphFromFile($event)" style="display: none;">
            <v-btn v-tooltip:end="'Load graph from file'" @click="triggerFileInput" :size="isMobile ? 'small' : 'large'"
              density="default">
              <v-icon>mdi-upload</v-icon> Load
            </v-btn>

            <v-btn v-tooltip:end="'Share graph as URL'" @mousedown.stop="saveGraphToDB()"
              :size="isMobile ? 'small' : 'large'" density="default">
              <v-icon>mdi-share</v-icon> Share
            </v-btn>
          </div>

          <!-- Button group outside SVG for z-index stacking -->
          <div class="button-group top">
            <!-- Buttons with icons and gaps -->
            <v-btn v-tooltip:end="'Pan around the graph'" :class="{ 'v-btn--active': mode === 'pan' }"
              @mousedown.stop="setMode('pan')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-cursor-move</v-icon> Move
            </v-btn>

            <v-btn v-tooltip:end="'This tool let\'s you move nodes around'"
              :class="{ 'v-btn--active': mode === 'drag' }" @mousedown.stop="setMode('drag')"
              :size="isMobile ? 'small' : 'large'" :disabled="animationRunning && !animationError ? 'disabled' : null"
              density="default">
              <v-icon>mdi-drag-variant</v-icon> Drag
            </v-btn>

            <v-btn v-tooltip:end="'Add a new node'" :class="{ 'v-btn--active': mode === 'add' }"
              @mousedown.stop="setMode('add')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-vector-circle</v-icon> Add Node
            </v-btn>

            <v-btn v-tooltip:end="'Add a new edge'" :class="{ 'v-btn--active': mode === 'addEdge' }"
              @mousedown.stop="setMode('addEdge')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-vector-line</v-icon> Add Edge
            </v-btn>

            <v-btn v-tooltip:end="'Edit the graph'" :class="{ 'v-btn--active': mode === 'edit' }"
              @mousedown.stop="setMode('edit')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-pencil</v-icon> Edit
            </v-btn>

            <v-btn v-tooltip:end="'Remove elements from the graph'" :class="{ 'v-btn--active': mode === 'remove' }"
              @mousedown.stop="setMode('remove')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-delete</v-icon> Remove
            </v-btn>
          </div>

          <div class="button-group bottom">
            <v-btn v-tooltip:end="'Go to start'" @mousedown.stop="panToNode('S')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-page-first</v-icon> Go to start
            </v-btn>

            <v-btn v-tooltip:end="'Go to end'" @mousedown.stop="panToNode('P')" :size="isMobile ? 'small' : 'large'"
              :disabled="animationRunning && !animationError ? 'disabled' : null" density="default">
              <v-icon>mdi-page-last</v-icon> Go to end
            </v-btn>

            <v-btn v-tooltip:end="'Start/Stop the animation'"
              :class="animationError ? 'error' : (animationRunning ? 'warning' : 'success')" @click="toggleAnimation"
              :size="isMobile ? 'small' : 'large'" density="default"
              :color="animationRunning ? 'error' : (animationError ? 'warning' : 'success')">
              <v-icon>{{ animationRunning ? 'mdi-stop' : (animationError ? 'mdi-replay' : 'mdi-play') }}</v-icon>
              {{ animationRunning ? 'Stop' : (animationError ? 'Restart' : 'Start') }}
            </v-btn>
          </div>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import { useTheme } from 'vuetify';
import { throttle } from 'lodash';
import Node from './Node.vue';
import Edge from './Edge.vue';
import Toucan from './Toucan.vue';

const apiUrl = window.location.origin + window.location.pathname + 'api/v1/';
const graphUrl = apiUrl + 'graph/';

export default {
  components: {
    Node,
    Edge,
    Toucan
  },
  setup() {
    const theme = useTheme()
    const currentTheme = theme.global.name

    return { theme, currentTheme };
  },
  data() {
    return {
      nodes: [
        { id: 'S', x: 100, y: 0 },
        { id: 'P', x: 250, y: 0 },
      ],
      edges: [],
      selectedNodeId: null,
      hoveredNodeId: null,
      selectedEdgeId: null,
      highlightedEdgeId: null,
      selectedNodeIdInEditMode: null,
      draggingNodeId: null,
      isPanning: false,
      offsetX: 0,
      offsetY: 0,
      panX: 500,
      panY: 500,
      panStartX: 0,
      panStartY: 0,
      toucanX: 0,
      toucanY: 0,
      toucanVisible: false,
      width: 800,
      height: 600,
      mode: 'pan',
      creatingEdge: null,
      edgeStartNode: null,
      addNodeHovered: null,
      animationRunning: false,
      animationError: false,
      animatedPath: [],
      pathIndex: 0,
      isMobile: true,
      isPathSet: false,
      data: null,
      unsavedChanges: true
    };
  },
  computed: {
    validEdges() {
      return this.edges.filter(edge => this.findNode(edge.from) && this.findNode(edge.to));
    },
    centerX() {
      return -this.panX;
    },
    centerY() {
      return -this.panY;
    }
  },
  mounted() {
    this.throttledMouseMove = throttle(this.onMouseMove, 16);
    this.detectMobile();

    window.addEventListener('resize', this.detectMobile);
    window.addEventListener('mousemove', this.throttledMouseMove);
    window.addEventListener('mouseup', this.stopInteraction);

    // Touch event listeners
    window.addEventListener('touchmove', this.onTouchMove, { passive: false });
    window.addEventListener('touchend', this.stopInteraction);
    window.addEventListener('touchcancel', this.stopInteraction);

    window.addEventListener('beforeunload', this.preventUnsavedChanges);

    this.unsavedChanges = true;
    this.panToNode('S');

    this.loadGraphFromDB();
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.detectMobile);
    window.removeEventListener('mousemove', this.throttledMouseMove);
    window.removeEventListener('mouseup', this.stopInteraction);

    window.removeEventListener('touchmove', this.onTouchMove);
    window.removeEventListener('touchend', this.stopInteraction);
    window.removeEventListener('touchcancel', this.stopInteraction);

    window.removeEventListener('beforeunload', this.preventUnsavedChanges);
  },
  methods: {
    findNode(id) {
      return this.nodes.find(node => node.id === id);
    },
    resetNodes() {
      this.animationRunning = false;
      this.animatedPath = [];

      this.nodes.forEach(node => {
        node.traversed = false;
      });
    },
    selectNode(id) {
      if (this.mode === 'remove') {
        this.removeNode(id);
      } else if (this.mode === 'edit') {
        if (id === 'S' || id === 'P') {
          alert('Node cannot be updated.');
          this.edgeStartNode = null;
          this.selectedNodeId = null;
          this.hoveredNodeId = null;
          this.selectedNodeIdInEditMode = null;
          return;
        }
        console.log(this.getGraphRelationsAndPositions());
        this.selectedNodeIdInEditMode = id;
        const newId = prompt('Enter new ID', id);
        if (newId && newId !== id) {
          if (!this.findNode(newId)) {
            this.updateNodeId(id, newId);
          } else {
            alert('Duplicate ID detected. Please enter a unique ID.');
          }
        }
        this.selectedNodeIdInEditMode = null;
      } else if (this.mode === 'addEdge') {
        if (!this.edgeStartNode) {
          this.edgeStartNode = id;
          this.selectedNodeId = id;
        } else {
          if (this.edgeStartNode !== id) {
            const existingEdge = this.edges.find(edge =>
              (edge.from === this.edgeStartNode && edge.to === id) ||
              (edge.from === id && edge.to === this.edgeStartNode)
            );
            if (!existingEdge) {
              const weight = prompt('Enter weight for new edge');
              if (weight) {
                const parsedWeight = parseInt(weight);
                if (Number.isInteger(parsedWeight) && parsedWeight > 0) {
                  this.addEdge(this.edgeStartNode, id, parsedWeight);
                  this.edgeStartNode = null;
                  this.selectedNodeId = null;
                  this.hoveredNodeId = null;
                  this.selectedNodeIdInEditMode = null;
                } else {
                  alert('Weight must be a positive integer.');
                  this.edgeStartNode = null;
                  this.selectedNodeId = null;
                  this.hoveredNodeId = null;
                  this.selectedNodeIdInEditMode = null;
                }
              }
            } else {
              alert('An edge already exists between these nodes.');
              this.edgeStartNode = null;
              this.selectedNodeId = null;
              this.hoveredNodeId = null;
              this.selectedNodeIdInEditMode = null;
            }
          } else {
            alert('Cannot connect a node to itself. Select a different node.');
            this.edgeStartNode = null;
            this.selectedNodeId = null;
            this.hoveredNodeId = null;
            this.selectedNodeIdInEditMode = null;
          }
        }
      } else if (this.mode === 'pan' || this.mode === 'drag') {
        this.selectedNodeId = id;
        this.edgeStartNode = null;
        this.hoveredNodeId = null;
        this.selectedNodeIdInEditMode = null;
      }
    },
    handleEdgeSelect(edge) {
      if (this.mode === 'remove') {
        this.removeEdge(edge.id);
      } else if (this.mode === 'edit') {
        this.selectedEdgeId = edge.id;
        const newWeight = prompt('Enter new weight', edge.weight);
        if (newWeight) {
          this.updateEdgeWeight(edge.id, parseInt(newWeight));
        }
        this.selectedEdgeId = null;
      }
    },
    startNodeDrag(event, nodeId) {
      if (this.mode === 'drag') {
        event.preventDefault();
        this.draggingNodeId = nodeId;
        const node = this.findNode(nodeId);
        if (node) {
          if (event.type === 'touchstart' && event.touches.length === 1) {
            console.log('Mobile touch start');
            this.offsetX = event.targetTouches[0].clientX - node.x - this.panX;
            this.offsetY = event.targetTouches[0].clientY - node.y - this.panY;
          } else {
            this.offsetX = event.clientX - node.x - this.panX;
            this.offsetY = event.clientY - node.y - this.panY;
          }
          console.log(event.type, this.offsetX, this.offsetY);
          if (event.type === 'touchend') {
            this.draggingNodeId = null;
          }
        }
      }
    },
    startInteraction(event) {
      if (this.animationRunning) {
        return;
      }

      if (this.mode === 'pan') {
        if (event.type === 'mousedown' || (event.type === 'touchstart' && event.touches.length === 1)) {
          this.isPanning = true;
          this.panStartX = event.type === 'mousedown' ? event.clientX : event.touches[0].clientX;
          this.panStartY = event.type === 'mousedown' ? event.clientY : event.touches[0].clientY;
        }
      }
      if (this.mode === 'drag' && this.draggingNodeId) {
        this.selectedNodeId = this.draggingNodeId;
      }
    },
    stopInteraction() {
      this.isPanning = false;
      this.draggingNodeId = null;
      this.selectedEdgeId = null;
      this.selectedNodeId = null;
      this.highlightedEdgeId = null;
      this.selectedNodeIdInEditMode = null;
      this.addNodeHovered = null;
    },
    onMouseMove(event) {
      if (this.draggingNodeId !== null && this.mode === 'drag') {
        const node = this.findNode(this.draggingNodeId);
        if (node) {
          node.x = event.clientX - this.offsetX - this.panX;
          node.y = event.clientY - this.offsetY - this.panY;
        }
      }
      if (this.isPanning) {
        const dx = event.clientX - this.panStartX;
        const dy = event.clientY - this.panStartY;
        this.panX += dx;
        this.panY += dy;
        this.panStartX = event.clientX;
        this.panStartY = event.clientY;
      }
    },
    onTouchMove(event) {
      if (this.draggingNodeId !== null && this.mode === 'drag') {
        const node = this.findNode(this.draggingNodeId);
        if (node) {
          const touch = event.targetTouches[0];
          node.x = touch.clientX - this.offsetX - this.panX;
          node.y = touch.clientY - this.offsetY - this.panY;
        }
      } else if (this.isPanning) {
        let clientX, clientY;
        if (event.type === 'touchmove') {
          clientX = event.touches[0].clientX;
          clientY = event.touches[0].clientY;
        }

        const dx = clientX - this.panStartX;
        const dy = clientY - this.panStartY;
        this.panStartX = clientX;
        this.panStartY = clientY;

        this.panX += dx;
        this.panY += dy;
      }
    },
    handleMouseOver(event) {
      const svgRect = this.$refs.svg.getBoundingClientRect();
      const x = event.clientX - svgRect.left - this.panX;
      const y = event.clientY - svgRect.top - this.panY;
      const hoveredNode = this.nodes.find(node => Math.abs(node.x - x) < 20 && Math.abs(node.y - y) < 20);

      if (this.mode === 'addEdge' || this.mode === 'edit' || this.mode === 'drag' || this.mode === 'remove') {
        this.hoveredNodeId = hoveredNode ? hoveredNode.id : null;
        if ((this.mode === 'edit' || this.mode === 'remove') && !hoveredNode) {
          const hoveredEdge = this.edges.find(edge => {
            const fromNode = this.findNode(edge.from);
            const toNode = this.findNode(edge.to);
            if (!fromNode || !toNode) return false;
            const dist = Math.abs(
              (toNode.y - fromNode.y) * x - (toNode.x - fromNode.x) * y + toNode.x * fromNode.y - toNode.y * fromNode.x
            ) /
              Math.sqrt(
                Math.pow(toNode.y - fromNode.y, 2) + Math.pow(toNode.x - fromNode.x, 2)
              );
            return dist < 20;
          });
          this.highlightedEdgeId = hoveredEdge ? hoveredEdge.id : null;
        } else {
          this.highlightedEdgeId = null;
        }
      } else if (this.mode === 'add') {
        this.addNodeHovered = { x, y };
      } else {
        this.hoveredNodeId = null;
        this.addNodeHovered = null;
        this.highlightedEdgeId = null;
      }
      if (this.draggingNodeId === null) {
        this.selectedNodeId = this.hoveredNodeId ? this.hoveredNodeId : null;
      }
    },
    handleSvgClick(event) {
      if (this.mode === 'add') {
        const svgRect = this.$refs.svg.getBoundingClientRect();
        const x = event.clientX - svgRect.left - this.panX;
        const y = event.clientY - svgRect.top - this.panY;
        const newId = prompt('Enter new ID');
        if (newId) {
          if (!this.findNode(newId)) {
            this.addNode(newId, x, y);
          } else {
            alert('Duplicate ID detected. Please enter a unique ID.');
            this.edgeStartNode = null;
            this.selectedNodeId = null;
            this.hoveredNodeId = null;
            this.selectedNodeIdInEditMode = null;
          }
        }
      } else {
        if (this.mode !== 'addEdge') {
          this.selectedNodeId = null;
          this.edgeStartNode = null;
        }
      }
      this.addNodeHovered = null;
    },
    addNode(id, x, y) {
      if (!this.findNode(id)) {
        this.nodes.push({ id, x, y });
      } else {
        alert('Duplicate ID detected. Please enter a unique ID.');
      }
    },
    removeNode(id) {
      if (id === 'S' || id === 'P') {
        alert('Node cannot be deleted.');
        this.edgeStartNode = null;
        this.selectedNodeId = null;
        this.hoveredNodeId = null;
        this.selectedNodeIdInEditMode = null;
        return;
      }

      this.nodes = this.nodes.filter(node => node.id !== id);
      this.edges = this.edges.filter(edge => edge.from !== id && edge.to !== id);
    },
    addEdge(from, to, weight) {
      if (!this.edges.find(edge => (edge.from === from && edge.to === to) || (edge.from === to && edge.to === from))) {
        this.edges.push({ id: `${from}-${to}`, from, to, weight });
      }
    },
    removeEdge(id) {
      this.edges = this.edges.filter(edge => edge.id !== id);
    },
    updateNodeId(oldId, newId) {
      const node = this.findNode(oldId);
      if (node) {
        node.id = newId;
        this.edges.forEach(edge => {
          if (edge.from === oldId) edge.from = newId;
          if (edge.to === oldId) edge.to = newId;
        });
      }
    },
    updateEdgeWeight(id, newWeight) {
      const edge = this.edges.find(edge => edge.id === id);
      if (edge) {
        edge.weight = newWeight;
      }
    },
    setMode(mode) {
      this.mode = mode;
      this.isPanning = false;
      this.draggingNodeId = null;
      this.edgeStartNode = null;
      this.selectedNodeId = null;
      this.hoveredNodeId = null;
      this.highlightedEdgeId = null;
      this.addNodeHovered = null;
    },
    getGraphRelations() {
      const nodes = this.nodes.map(node => node.id);
      const edges = this.edges.map(edge => ({
        from: edge.from,
        to: edge.to,
        weight: edge.weight
      }));

      const graphRelations = {
        nodes,
        edges
      };
      console.log(graphRelations);

      return graphRelations;
    },
    getGraphRelationsAndPositions() {
      const nodes = this.nodes.map(node => ({
        id: node.id,
        x: node.x,
        y: node.y
      }));

      const edges = this.edges.map(edge => ({
        from: edge.from,
        to: edge.to,
        weight: edge.weight
      }));

      const graphRelationsAndPositions = {
        nodes,
        edges
      };
      console.log(graphRelationsAndPositions);

      return graphRelationsAndPositions;
    },

    async toggleAnimation() {
      this.animationError = false;
      this.toucanVisible = false;

      if (!this.animationRunning) {
        await this.startAnimation();
      } else {
        this.animationRunning = false;
        this.toucanVisible = false;
      }
    },

    async startAnimation() {
      try {
        const response = await fetch(graphUrl + 'shortest-path', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            nodes: this.nodes.map(node => node.id),
            edges: this.edges.map(edge => ({
              from: edge.from,
              to: edge.to,
              weight: edge.weight
            }))
          })
        });

        const data = await response.json();
        if (data.path) {
          await this.panToNode('S');
          this.animationRunning = true;

          this.animatedPath = [];
          this.animatedPath.push(this.findNode('S'));

          this.animatedPath.push(...data.path.map(nodeId => this.findNode(nodeId)));
          this.pathIndex = 0;

          this.data = data;

          setTimeout(() => {
            this.toucanVisible = true;
            this.animationError = false;
            this.animateToucan();
          }, 500);
        } else {
          console.error('Path data is not valid:', data);
          setTimeout(() => {
            this.animationError = true;
            this.resetNodes();
            alert('No path found.');
          }, 200);
        }
      } catch (error) {
        console.error('Error fetching path:', error);
        setTimeout(() => {
          this.animationError = true;
          this.resetNodes();
          alert('No path found.');
        }, 200);
      }
    },

    async animateToucan() {
      if (this.animationRunning && this.pathIndex < this.animatedPath.length) {
        const node = this.animatedPath[this.pathIndex];
        await this.panToNode(node.id);

        node.traversed = true;

        this.pathIndex++;
        setTimeout(this.animateToucan, 500);
      } else {
        this.animationRunning = false;
        this.toucanVisible = false;
        setTimeout(this.resetNodes, 1000);
        alert('Distance traveled: ' + this.data.distance);
      }
    },

    async panToNode(nodeId) {
      const node = this.findNode(nodeId);
      if (node) {
        if (nodeId === 'S' && this.animationRunning === true) {
          this.toucanX = node.x + this.panX;
          this.toucanY = node.y + this.panY;
        } else {
          const svgRect = this.$refs.svg.getBoundingClientRect();
          const centerX = svgRect.width / 2;
          const centerY = svgRect.height / 2;

          const currentPanX = this.panX;
          const currentPanY = this.panY;

          const targetX = -node.x + centerX - currentPanX;
          const targetY = -node.y + centerY - currentPanY;

          const duration = 500;
          let startTime = null;

          const animate = (currentTime) => {
            if (!startTime) {
              startTime = currentTime;
            }

            const elapsedTime = currentTime - startTime;
            const progress = Math.min(elapsedTime / duration, 1);

            const easingProgress = this.easeInOutQuad(progress);

            this.panX = currentPanX + targetX * easingProgress;
            this.panY = currentPanY + targetY * easingProgress;

            const dx = (node.x + this.panX) - this.toucanX;
            const dy = (node.y + this.panY) - this.toucanY;
            this.toucanX += dx * easingProgress;
            this.toucanY += dy * easingProgress;

            if (progress < 1) {
              requestAnimationFrame(animate);
            }
          };

          requestAnimationFrame(animate);
        }
      }
    },

    adjustBottomButtonGroup() {
      // Ensure bottom button group remains visible when the keyboard is open
      if (this.isMobile) {
        const bottomButtonGroup = document.querySelector('.button-group.bottom');
        if (bottomButtonGroup) {
          bottomButtonGroup.style.visibility = 'visible';
          setTimeout(() => {
            const rect = bottomButtonGroup.getBoundingClientRect();
            const isVisible = rect.bottom <= window.innerHeight;
            if (!isVisible) {
              bottomButtonGroup.style.visibility = 'hidden';
            }
          }, 300); // Adjust delay as needed for keyboard to open
        }
      }
    },

    detectMobile() {
      this.isMobile = window.innerWidth <= 768 || window.innerHeight <= 520;
    },

    easeInOutQuad(t) {
      return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    },

    handleTouchMove(event) {
      event.preventDefault();
      this.handleMouseOver(event.touches[0]);
    },

    triggerFileInput() {
      this.$refs.fileInput.click();
    },

    saveGraphToFile() {
      const data = {
        nodes: this.nodes,
        edges: this.edges
      };
      const json = JSON.stringify(data, null, 2);
      const blob = new Blob([json], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "graph.json";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      this.unsavedChanges = false;
    },

    loadGraphFromFile(event) {
      const file = event.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (e) => {
          const json = e.target.result;
          try {
            const data = JSON.parse(json);
            this.nodes = data.nodes || [];
            this.edges = data.edges || [];
          } catch (error) {
            alert("Failed to load graph: Invalid JSON format.");
          }
        };
        reader.readAsText(file);
      }
    },

    async loadGraphFromDB() {
      try {
        const urlParams = new URLSearchParams(window.location.search);
        const hash = urlParams.get('graph');

        if (!hash) {
          console.log('Graph hash parameter (?graph=) is missing.');
          return;
        }

        console.log('Fetching graph with hash:', hash);

        const response = await fetch(graphUrl + hash, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json'
          }
        });

        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const graph = await response.json();
        console.log('Fetched graph:', graph);

        try {
          this.nodes = graph.nodes || [];
          this.edges = graph.edges || [];
        } catch (error) {
          alert("Failed to load graph: Invalid JSON format.");
        }
      } catch (error) {
        console.error('Error fetching graph:', error);
      }
    },

    async saveGraphToDB() {
      try {
        const data = {
          nodes: this.nodes,
          edges: this.edges
        };
        const json = JSON.stringify(data, null, 2);

        const response = await fetch(graphUrl + 'store', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: json
        });

        if (!response.ok) {
          const errorResponse = await response.json();
          if (errorResponse.hash) {
            const graphUrl = `${window.location.origin}?graph=${errorResponse.hash}`;

            alert(`Graph already exists. Link to the resource: ${graphUrl}`);
            console.log(`Graph already exists with hash: ${errorResponse.hash}`);

            return errorResponse.hash;
          } else {
            alert('Graph couldn\'t be saved');
            throw new Error(`Failed to save graph: ${errorResponse.error.message}`);
          }
        }

        const responseData = await response.json();
        if (responseData.hash) {
          const graphUrl = `${window.location.origin}?graph=${responseData.hash}`;
          alert(`Graph saved successfully. Link to the resource: ${graphUrl}`);
          console.log(`Graph saved successfully with hash: ${responseData.hash}`);

          return responseData.hash;
        } else {
          alert('Graph couldn\'t be saved');
          throw new Error('Failed to save graph: Missing hash in response');
        }
      } catch (error) {
        alert('Graph couldn\'t be saved');
        alert(`Error saving graph: ${error.message}`);

        throw error;
      }
    },

    preventUnsavedChanges(e) {
      if (this.unsavedChanges) {
        e.preventDefault();
        e.returnValue = '';

        return 'You have unsaved changes. Are you sure you want to leave?';
      }
    }
  }
};
</script>

<style scoped>
.fill-height {
  position: relative;
  height: 100%;
  width: 100%;
  margin: 0;
  padding: 0;
  overflow: visible;
}

.svg-container {
  position: relative;
  width: 100%;
  height: 100%;
  overscroll-behavior: contain;
  overflow: visible;
}

.graph-svg {
  position: relative;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.hand-cursor {
  cursor: move;
}

.button-group {
  position: absolute;
  z-index: 10;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px;
}

.button-group.top {
  top: 16px;
  right: 16px;
}

.button-group.left {
  left: 16px;
  top: 16px;
}

.button-group.bottom {
  bottom: 16px;
  left: 16px;
}

.button-group.mobile {
  flex-direction: row;
  gap: 4px;
  padding: 4px;
}

.button-group.mobile .v-btn {
  min-width: auto;
  padding: 6px 12px;
}
</style>
