function data =sifreadHeader(file)
f=fopen(file,'r','n','US-ASCII');
if f < 0
   error('Could not open the file.');
end
if ~isequal(fgetl(f),'Andor Technology Multi-Channel File')
   fclose(f);
   error('Not an Andor SIF image file.');
end
skipLines(f,1);
data=readSection(f);
fclose(f);


%Read a file section.
%
% f      File handle
% info   Section data
% next   Flags if another section is available
%
function info=readSection(f)
o=fscanf(f,'%d',6); %% scan over the 6 Bytes
info.temperature=o(6); %o(6)
skipBytes(f,10);%% skip the space (why 10 not 11?)
o=fscanf(f,'%f',5);%% Scan the next 5 bytes
info.delayExpPeriod=o(2);
info.exposureTime=o(3);
info.accumulateCycles=o(5);
info.accumulateCycleTime=o(4);
skipBytes(f,2); %% skip 2 more bytes
o=fscanf(f,'%f',2);
info.stackCycleTime=o(1);
info.pixelReadoutTime=o(2);
o=fscanf(f,'%d',3);
info.gainDAC=o(3);
skipLines(f,1);
info.detectorType=readLine(f);
info.detectorSize=fscanf(f,'%d',[1 2]); %% I think everythings ok to here
info.fileName=readString(f);
%skipLines(f,4); %% changed this from 26 from Ixon camera now works for Newton. %%%%%%%%%%%%%%%%%%%%%%% ALL YOU NEED TO CHANGE

skipUntil(f,'65538')
skipUntil(f,'65538')

% Added the following to extract the center wavelength and grating
o=fscanf(f,'%f',8);
info.centerWavelength = o(4);
info.grating = round(o(7));

%skipLines(f,10); % added this in
skipUntil(f,'65539')
skipUntil(f,'65538') %NEW
backOneLine(f) %NEW
o=fscanf(f,'65538 %d %d %d %d %d %d %d %d 65538 %d %d %d %d %d %d',14);
if o(2) == 0
    split = 1;
else
    split = 0;
end


skipUntilChar(f,'.')
backOneLine(f)

o=fscanf(f,'%f',4);
info.minWavelength = o(1);
info.stepWavelength = o(2);
info.step1Wavelength = o(3);
info.step2Wavelength = o(4);
info.maxWavelength = info.minWavelength + info.detectorSize(1)*info.stepWavelength;

% Create wavelength, energy and frequency axes.
da = 1:(info.detectorSize(1));
info.axisWavelength = info.minWavelength + da.*(info.stepWavelength + da.*info.step1Wavelength + da.^2*info.step2Wavelength);
info.axisEnergy = convertUnits(info.axisWavelength,'nm','eV'); % energy in eV
info.axisGHz = convertUnits(info.axisWavelength,'nm','GHz');

%skipUntil(f,'Wavelength');
%backOneLine(f)
%backOneLine(f)

skipUntil(f,'Pixel number')
backOneLine(f)
skip = fscanf(f,'%12c',1);
info.frameAxis = fscanf(f,'%d',1); %'Pixel number'

skip = fscanf(f,'%7c',1);
info.dataType = fscanf(f,'%d',1);  %'Counts' %% gets this from andor file

skip = fscanf(f,'%13c',1);
o=fscanf(f,'65541 %d %d %d %d %d %d %d %d 65538 %d %d %d %d %d %d',14); %% 14 is lines in o?
temp = o;
info.imageArea=[o(1) o(4) o(6);o(3) o(2) o(5)];
info.frameArea=[o(9) o(12);o(11) o(10)];
info.frameBins=[o(14) o(13)];
s=(1 + diff(info.frameArea))./info.frameBins;
z=1 + diff(info.imageArea(5:6));
info.height = s(2);
info.width = s(1);
info.kineticLength = o(5);





%Read a character string.
%
% f      File handle
% o      String
%
function o=readString(f)
n=fscanf(f,'%d',1);
if isempty(n) || n < 0 || isequal(fgetl(f),-1)
   fclose(f);
   error('Inconsistent string.');
end
o=fread(f,[1 n],'uint8=>char');


%Read a line.
%
% f      File handle
% o      Read line
%
function o=readLine(f)
o=fgetl(f);
if isequal(o,-1)
   fclose(f);
   error('Inconsistent image header.');
end
o=deblank(o);


%Skip bytes.
%
% f      File handle
% N      Number of bytes to skip
%
function skipBytes(f,N)
[ret,n]=fread(f,N,'uint8');
if n < N
   fclose(f);
   error('Inconsistent image header.');
end


%Skip lines.
%
% f      File handle
% N      Number of lines to skip
%
function skipLines(f,N)
for n=1:N
   if isequal(fgetl(f),-1)
      fclose(f);
      error('Inconsistent image header.');
   end
end





% Skip to the line starting with str.

function skipUntil(f,str)

ls = length(str);
stringFound = 0;
while ~stringFound
    % Read line
    s = readLine(f);

    if length(s)>=ls && strcmp(s(1:ls), str) % check if string found.
        stringFound = 1;
    else
        stringFound = 0;
    end
end

% Skip to the first incidence of the character c.
function skipUntilChar(f,c)
stringFound = 0;
while ~stringFound
    % Read line
    cread=fscanf(f,'%c',1);
    if cread==c
        stringFound=1;
    end
end


function backOneLine(f)
newLineFound = 0;
numTimes = 0;
while ~newLineFound
    fseek(f,-2,'cof');
    c=fscanf(f,'%c',1);
    newLineFound = c==10;
    numTimes = numTimes+1;
end
%
% if numTimes<=2
% fseek(f,-4,'cof');
% numTimes = 0;
% while ~newLineFound
%     fseek(f,-2,'cof');
%     c=fscanf(f,'%d',1)
%     newLineFound = c==10;
%     numTimes = numTimes+1;
% end
% end
