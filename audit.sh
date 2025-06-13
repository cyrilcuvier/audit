#!/bin/bash

# Output files
OUTPUT_FILE="namespaces_output.txt"
> "$OUTPUT_FILE"

# List all clusters from the Rancher API v3
curl -sk -H "Authorization: Bearer $TOKEN" "https://localhost/v3/clusters?limit=-1" \
| sed 's/},{/}\n{/g' \
| while read line; do
    # Extract the cluster ID and name
    id=$(echo "$line" | grep -o '"id":"[^"]*"' | head -n1 | cut -d':' -f2 | tr -d '"')
    name=$(echo "$line" | grep -o '"name":"[^"]*"' | head -n1 | cut -d':' -f2 | tr -d '"')

    if [ -n "$id" ] && [ -n "$name" ]; then
        # Write the cluster and its ID to the output file
        echo "🔸 Cluster: $name (ID: $id)" >> "$OUTPUT_FILE"

        # Get namespaces for the current cluster
        echo "  Retrieving namespaces for cluster: $id" >> "$OUTPUT_FILE"
        
        # Call the Rancher API v3 to list namespaces for this cluster
        response=$(curl -sk -H "Authorization: Bearer $TOKEN" \
          "https://localhost/v3/clusters/$id/namespaces")

        # Check if the response contains errors
        if echo "$response" | grep -q '"baseType":"error"'; then
            echo "    Error: Unable to retrieve namespaces for cluster $id" >> "$OUTPUT_FILE"
        else
            # Extract namespaces
            namespaces=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name": "//g' | sort -u)

            # If 'longhorn-system' is found, retrieve DaemonSets
            if echo "$namespaces" | grep -q 'longhorn-system'; then
                echo "    Namespace 'longhorn-system' found, retrieving DaemonSets..." >> "$OUTPUT_FILE"
                # Use Kubernetes API to get DaemonSets in the 'longhorn-system' namespace
                daemonset_response=$(curl -sk -H "Authorization: Bearer $TOKEN" \
                    "https://localhost/k8s/clusters/$id/apis/apps/v1/namespaces/longhorn-system/daemonsets")
                
                # Create the directory with the cluster name and namespace
                mkdir -p "./results/$name/longhorn-system"
                echo "$daemonset_response" > "./results/$name/longhorn-system/longhorn_infos.json"
                echo "    DaemonSet 'longhorn-manager' found, details saved to file." >> "$OUTPUT_FILE"
                echo "    Number of pods in 'longhorn-manager': $(echo "$daemonset_response" | grep -o '"currentNumberScheduled":[^,]*' | cut -d: -f2)" >> "$OUTPUT_FILE"
            fi

            # If 'cattle-neuvector-system' is found, retrieve DaemonSets
            if echo "$namespaces" | grep -q 'cattle-neuvector-system'; then
                echo "    Namespace 'cattle-neuvector-system' found, retrieving DaemonSets..." >> "$OUTPUT_FILE"
                # Use Kubernetes API to get DaemonSets in the 'cattle-neuvector-system' namespace
                daemonset_response=$(curl -sk -H "Authorization: Bearer $TOKEN" \
                    "https://localhost/k8s/clusters/$id/apis/apps/v1/namespaces/cattle-neuvector-system/daemonsets")
                
                # Create the directory with the cluster name and namespace
                mkdir -p "./results/$name/cattle-neuvector-system"
                echo "$daemonset_response" > "./results/$name/cattle-neuvector-system/neuvector_infos.json"
                echo "    DaemonSet 'neuvector-enforcer-pod' found, details saved to file." >> "$OUTPUT_FILE"
                echo "    Number of pods in 'neuvector-enforcer-pod': $(echo "$daemonset_response" | grep -o '"currentNumberScheduled":[^,]*' | cut -d: -f2)" >> "$OUTPUT_FILE"
            fi
        fi
    fi
done

echo "Output saved to the file $OUTPUT_FILE"
