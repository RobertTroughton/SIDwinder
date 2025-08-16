/**
 * TSCrunch Graph Algorithms
 * JavaScript port by Claude
 * Original by Antonio Savona
 */

// Efficient binary heap priority queue for Dijkstra's algorithm
class PriorityQueue {
    constructor() {
        this.heap = [];
        this.size = 0;
    }
    
    enqueue(item, priority) {
        const node = { item, priority };
        this.heap[this.size] = node;
        this._heapifyUp(this.size);
        this.size++;
    }
    
    dequeue() {
        if (this.size === 0) return undefined;
        
        const min = this.heap[0];
        this.size--;
        
        if (this.size > 0) {
            this.heap[0] = this.heap[this.size];
            this._heapifyDown(0);
        }
        
        return min;
    }
    
    isEmpty() {
        return this.size === 0;
    }
    
    _heapifyUp(index) {
        if (index === 0) return;
        
        const parentIndex = Math.floor((index - 1) / 2);
        if (this.heap[index].priority < this.heap[parentIndex].priority) {
            [this.heap[index], this.heap[parentIndex]] = [this.heap[parentIndex], this.heap[index]];
            this._heapifyUp(parentIndex);
        }
    }
    
    _heapifyDown(index) {
        const leftChild = 2 * index + 1;
        const rightChild = 2 * index + 2;
        let smallest = index;
        
        if (leftChild < this.size && this.heap[leftChild].priority < this.heap[smallest].priority) {
            smallest = leftChild;
        }
        
        if (rightChild < this.size && this.heap[rightChild].priority < this.heap[smallest].priority) {
            smallest = rightChild;
        }
        
        if (smallest !== index) {
            [this.heap[index], this.heap[smallest]] = [this.heap[smallest], this.heap[index]];
            this._heapifyDown(smallest);
        }
    }
}

/**
 * Dijkstra's shortest path algorithm
 * @param {Object} graph - Graph represented as adjacency list
 * @param {number} start - Starting node
 * @returns {Object} Object containing distances and predecessors
 */
function dijkstra(graph, start) {
    const distances = {};
    const predecessors = {};
    const visited = new Set();
    const pq = new PriorityQueue();
    
    // Find all nodes (both sources and targets)
    const allNodes = new Set();
    for (const node in graph) {
        allNodes.add(parseInt(node));
        for (const neighbor in graph[node]) {
            allNodes.add(parseInt(neighbor));
        }
    }
    
    // Initialize distances for all nodes
    for (const node of allNodes) {
        distances[node] = Infinity;
        predecessors[node] = -1;
    }
    distances[start] = 0;
    
    pq.enqueue(start, 0);
    
    while (!pq.isEmpty()) {
        const {item: current, priority: currentDistance} = pq.dequeue();
        
        // Skip if we've already processed this node with a better distance
        if (visited.has(current)) continue;
        visited.add(current);
        
        // Skip if this distance is outdated (we found a better path)
        if (currentDistance > distances[current]) continue;
        
        if (!graph[current]) continue;
        
        for (const neighbor in graph[current]) {
            const weight = graph[current][neighbor];
            const distance = distances[current] + weight;
            const neighborInt = parseInt(neighbor);
            
            if (distance < distances[neighborInt]) {
                distances[neighborInt] = distance;
                predecessors[neighborInt] = parseInt(current);
                pq.enqueue(neighborInt, distance);
            }
        }
    }
    
    return {distances, predecessors};
}

/**
 * Extract path from predecessors array
 * @param {Object} predecessors - Predecessors from Dijkstra's algorithm
 * @param {number} target - Target node
 * @returns {Array} Array of [start, end] pairs representing the path
 */
function getPath(predecessors, target) {
    const path = [];
    let current = target;
    
    while (predecessors[current] >= 0) {
        path.unshift([predecessors[current], current]);
        current = predecessors[current];
    }
    
    return path;
}

/**
 * Build a graph from tokens for compression
 * @param {Object} tokenGraph - Token graph with keys as "start,end" and values as tokens
 * @returns {Object} Graph suitable for Dijkstra's algorithm
 */
function buildDijkstraGraph(tokenGraph) {
    const dijkstraGraph = {};
    let tokenCount = 0;
    
    for (const [key, token] of Object.entries(tokenGraph)) {
        const [start, end] = key.split(',').map(n => parseInt(n));
        
        if (!dijkstraGraph[start]) {
            dijkstraGraph[start] = {};
        }
        dijkstraGraph[start][end] = token.getCost();
        tokenCount++;
    }
    
    return dijkstraGraph;
}

export {
    PriorityQueue,
    dijkstra,
    getPath,
    buildDijkstraGraph
};