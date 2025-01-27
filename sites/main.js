let byProgram = false;
let timerId;

function reformat(event, ui) {
  const input = editor.getValue();
  const formattingMode = q('#formatting-mode').value;
  try {
    toastr.clear();
    if (formattingMode === 'compact') {
      outputArea.setValue(spfmt.reformat(input, 2, true));
    } else if (formattingMode === 'JSON-LD') {
      outputArea.setValue(spfmt.sparql2Jsonld(input, false));
    } else if (formattingMode === 'Turtle') {
      outputArea.setValue(spfmt.sparql2Turtle(input, false));
    } else {
      outputArea.setValue(spfmt.reformat(input, 2, false));
    }
  } catch (err) {
    toastr.remove();
    outputArea.setValue(input);
    let title = 'SyntaxError';
    if (err.location) {
      const startLine = err.location.start.line;
      const endLine = err.location.end.line;
      const startCol = err.location.start.column;
      const endCol = err.location.end.column;
      if (startLine == endLine) {
        title += ` at line:${startLine}(col:${startCol}-${endCol})\n`;
      } else {
        title += ` at line:${startLine}(col:${startCol})-${endLine}(col:${endCol})\n`;
      }
      outputArea.setSelection({line: startLine-1, ch: startCol-1}, {line: endLine-1, ch: endCol-1});
    }
    toastr.options = {
      timeOut: 0,
      extendedTimeOut: 0,
      closeButton: true,
      preventDuplicates: true
    }
    let message = '';
    if (err.message) {
      message = err.message;
      // console.log(message);
      message = message.replace(/^Expected /, 'Expected:<br>&ensp;');
      message = message.replace(/ but .* found.$/, '');
      message = message.replace('end of input', '');
      message = message.replace('[ \\t]', '');
      message = message.replace('[\\n\\r]', '');
      message = message.replace(/\[[^\dAa]\S+\]/g, '');
      message = message.replace('"#"', '');
      message = message.replace(/"(\S+)"/g, '$1');
      message = message.replace(/'"'/, '"');
      message = message.replace(/\\"/g, '"');
      message = message.replace('or ', ', ');
      message = message.replace(/(, )+/g, '<br>&ensp;');
    }
    toastr.error(message, title);
  }
}

function onChanged(delta) {
  if (!byProgram) {
    clearTimeout(timerId);
    timerId = setTimeout(reformat, 500);
  } else {
    byProgram = false;
  }
}

editor.on('change', onChanged);

q('#formatting-mode').addEventListener('change', reformat);

q('#query-select').addEventListener('change', (event) => {
  if (event.target.value === '') {
    editor.setValue('SELECT * WHERE { ?s ?p ?o. } LIMIT 10');
  } else {
    let url = `https://raw.githubusercontent.com/sparqling/sparql-formatter/main/sparql11-query/${event.target.value}`;
    axios.get(url).then((response) => {
      editor.setValue(response.data);
    });
  }
});

q('#copy-button').addEventListener('click', () => {
  navigator.clipboard.writeText(outputArea.getValue());
});

document.addEventListener('DOMContentLoaded', function (event) {
  let url = `https://api.github.com/repos/sparqling/sparql-formatter/contents/sparql11-query`;
  axios.get(url).then((response) => {
    const selectNode = q('#query-select');
    selectNode.innerHTML = '';

    let firstOption = document.createElement('option');
    firstOption.innerText = '';
    selectNode.appendChild(firstOption);

    for (let object of response.data) {
      if (object.name.endsWith('.rq')) {
        let option = document.createElement('option');
        option.innerText = object.name;
        selectNode.appendChild(option);
      }
    }
  });

  const inputArea = document.getElementById("input-area");
  const formattedArea = document.getElementById("formatted-area");
  const resizeHandle = document.getElementById("resize-handle");
  let isResizing = false;
  resizeHandle.addEventListener("mousedown", (e) => {
    e.preventDefault();
    isResizing = true;
  });
  document.addEventListener("mousemove", (e) => {
    if (isResizing) {
      const newInputWidth = e.clientX - inputArea.getBoundingClientRect().left;
      const newFormattedWidth = window.innerWidth - e.clientX;
      const newInputPercent = newInputWidth / window.innerWidth * 100;
      const newFormattedPercent = newFormattedWidth / window.innerWidth * 100;
      inputArea.style.width = `${newInputPercent}%`;
      formattedArea.style.width = `${newFormattedPercent}%`;
    }
  });
  document.addEventListener("mouseup", () => {
    isResizing = false;
  });
});
